public class GPSO_ExternalObjectUtilities {
   /**
     * Description: Method getsObjectFields
     * 
     * This method returns Sections and the Fields (name, value, type, relatedobjectname) in each section to 
     * be displayed in Lightning component.
     * 
     * The Page Layout is determined based on the PageAssignments for the Knowledge Record Type and the User Profile.
     * The Page Layout name is retrieved using Tooling API.
     * 
     * Sections and its Fields are retrieved from the Page Layout.
     * If a field in a section is not accessible to the user or if it is null, then that field is not returned.
     * If all the fields in a section is not accessible to the user or if it is null, then that section is not returned.
     * 
     *
     * @param  recordId Id  - The Id of the sObject the user is viewing.
     *
     * @return List<Section>
     */ 
    @AuraEnabled
    public static List<Section> getsObjectFields(ID recordId) {
        // The list of sections to return
        List<Section> listSections = new List<Section>();

        // Get page layout name for the Current User using Tooling API
        String sObjectName = '';
        String pageLayout = getLayoutUsingRecordTypeName(recordId);
        //String pageLayout = getLayoutUsingPageAssignments(recordId);
        System.debug('pageLayout: ' + pageLayout);

        List<Metadata.Metadata> components =
            Metadata.Operations.retrieve(Metadata.MetadataType.Layout, new String[]{pageLayout});
    
        if (components.size() < 1) {
            // Return empty list of sections (no such page layout OR page layout name not mapped to record id)
            Section errorSection = new Section('No page layout found or mapped to the current record type', 1);
            listSections.add(errorSection);
            errorSection.fields.add(new Field('Record Id='+recordId, 1, '', '', ''));              
            errorSection.fields.add(new Field('Record Type/Page Layout Name='+pageLayout, 2, '', '', ''));    
            return listSections;
        }

        Metadata.Layout layout = (Metadata.Layout) components.get(0);

        // Get the fields in each section of the layout in a Set.
        Set<String> setFields = new Set<String>();
        if (layout.layoutSections != null) {
          for (Metadata.LayoutSection section : layout.layoutSections) {
              if (section.layoutColumns != null) {
                  for (Metadata.LayoutColumn column : section.layoutColumns) {
                      if (column.layoutItems != null) {
                          for (Metadata.LayoutItem item : column.layoutItems) {
                              if (item.field != null) {
                                  setFields.add(item.field);
                              }
                          }
                      }
                  }
              }
           }
        }
    
        // Workaround for retreiving sObject name when getSObjectType() returns standard object name with 'x0Nxxxxxx' record Id
        // Currently this does not seem to be required - 'x0Nxxxxxx' record Ids are corretly returning external API sObject names
        /*
        if (String.isNotBlank(recordId) && String.valueOf(recordId).length() >= 15) {
            if (String.valueOf(recordId).startsWithIgnoreCase('x01')) {
                sObjectName = 'ExternalAccount__x';
            } else {  
                sObjectName = recordId.getSObjectType().getDescribe().getName();  
            }
        }*/

        sObjectName = recordId.getSObjectType().getDescribe().getName();        
        Map<String,Schema.SObjectField> mapFields = Schema.getGlobalDescribe().get(sObjectName).getDescribe().fields.getMap();        
    
        // Collect fields that are accessible
        Set<String> setAccessibleFields = new Set<String>();
        
        // Create a query using fields in the layout and field accessibility.
        String query = 'SELECT Id';
        for (String field : setFields) {
            Schema.DescribeFieldResult dfr = mapFields.get(field).getDescribe();
            // Add to query only if the field is accessible to the user
            if (dfr.isAccessible()) {
    
              // o6-17-2020 This field is accessible
              setAccessibleFields.add(field);
              
              query += ', ' + field;
    
              // Check if it is a lookup field.
              // For lookup field get the Name field of child object.
              if (dfr.getType() == Schema.DisplayType.Reference) {
                  String lookupNameField = field;
                  if (field.endsWithIgnoreCase('__c')) {
                      //for custom fields change __c to __r
                      lookupNameField = lookupNameField.left(lookupNameField.length() - 1) + 'r';
                  }
                  else if (field.endsWithIgnoreCase('Id')) {
                      //for standard fields remove Id. Example LastModifiedById to LastModifiedBy
                      lookupNameField = lookupNameField.left(lookupNameField.length() - 2);
                  }
    
                  query += ', ' + lookupNameField + '.Name';
              }
            }
        }
        query += ' FROM ' + sObjectName + ' WHERE Id = \'' + recordId + '\' LIMIT 1';
    
        System.debug(query);
        sObject recordDetail = Database.query(query);
    
    
        // The list of Sections to return.
        Integer secNumber = 0;
        Integer fldNumber = 0;
    
        Section currSection = null;
    
        if (layout.layoutSections != null) {
            for (Metadata.LayoutSection section : layout.layoutSections) {
                // Starting new Section in Layout
                currSection = null;
                if (section.layoutColumns != null) {
                    for (Metadata.LayoutColumn column : section.layoutColumns) {
                        if (column.layoutItems != null) {
                            for (Metadata.LayoutItem item : column.layoutItems) {
    
                                // 06-17-2020 Also check if the field is accessible
                                //if (item.field != null) {
                                if (item.field != null && setAccessibleFields.contains(item.field)) {
                                    // Get the value of this field
                                    Object value = recordDetail.get(item.field);
    
                                    // Check if the value is not null.
                                    // The value can be null in the record or if the field is not accessible
                                    if (value != null) {
                                        // First field is getting added to a new Section, so create a new Section
                                        if (currSection == null) {
                                            currSection = new Section(section.label, ++secNumber);
                                            listSections.add(currSection);
                                            fldNumber = 0;
                                        }
    
                                        // Add the field with the label and vale to the section.
                                        Schema.DescribeFieldResult dfr = mapFields.get(item.field).getDescribe();
    
                                        Object lookupNameFieldValue = null;
                                        
                                        // Check if it is a lookup field.
                                        // For lookup field get the Name field of child object.
                                        if (dfr.getType() == Schema.DisplayType.Reference) {
                                            String lookupNameField = item.field;
                                            if (item.field.endsWithIgnoreCase('__c')) {
                                                //for custom fields change __c to __r
                                                lookupNameField = lookupNameField.left(lookupNameField.length() - 1) + 'r';
                                            }
                                            else if (item.field.endsWithIgnoreCase('Id')) {
                                                //for standard fields remove Id. Example LastModifiedById to LastModifiedBy
                                                lookupNameField = lookupNameField.left(lookupNameField.length() - 2);
                                            }
    
                                            lookupNameFieldValue = recordDetail.getSObject(lookupNameField).get('Name');
                                        }
    
                                        
                                        currSection.fields.add(new Field(dfr.getLabel(), ++fldNumber, dfr.getType().name(), value, lookupNameFieldValue));                                        
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        System.debug('Returning Sections: ' + JSON.serialize(listSections));
    
        return listSections;    
    }
    
    
    /**
     * Description: Method getLayoutUsingPageAssignments
     * 
     * This method returns the name of the Page Layout which is determined based on the Page Layout Assignments
     * which themselves are a function of the user's profile and Object Id for custom or external objects.  Note: For 
     * standard objects Page Layout Assignents are typically a function of profile and record type (also supported).
     * 
     * The Page Layout name is retrived using Tooling API.
     * 
     * If there is error or if it is called from Test class, the page Layout name is retrieved from the
     * custom metadata setting xxxPageLayoutSetting__mdt.
     *
     * @param  recordId Id  - The Id of the record that the user is viewing.
     *
     * @return String - The name of the Page Layout
     */
    
    public static String getLayoutUsingRecordTypeName(ID recordId) {
        String pageLayoutName = ''; 
        String recordTypeName = '';
        String sObjectId = '';
        String sObjectName = '';
        String query = '';
    
        // Get the record type id of the external record
        sObjectName = recordId.getSObjectType().getDescribe().getName();  
        if (String.isNotBlank(sObjectName)) {
            query = 'SELECT RecordTypeId__c FROM ' + sObjectName + ' WHERE Id = :recordId LIMIT 1';
            sObject theRecord = Database.query(query);
            if (theRecord != null && String.isNotBlank((String)theRecord.get('RecordTypeId__c'))) {
                String recordTypeId = (String)theRecord.get('RecordTypeId__c');
                // Get the record type name to be used for page layout lookup (assumes record type name == page layout name)
                if (String.isNotBlank(recordTypeId)) {
                    List<SO_ExternalAccountRecordTypes__mdt> EART = [SELECT Record_Type_Id__c, Page_Layout_Name__c FROM SO_ExternalAccountRecordTypes__mdt 
                        WHERE Record_Type_Id__c = :recordTypeId];
                    if (EART.size() >= 1) {
                        pageLayoutName = EART[0].Page_Layout_Name__c;
                    }
                }
            }
        }
        if (String.isBlank(pageLayoutName)) {
            pageLayoutName = 'Unknown';
        }
        return pageLayoutName;
    }

    public static String getLayoutUsingPageAssignments(ID recordId) {
    
        // Get default layout name from metadata ExternalAccountLayoutSetting__mdt (LayoutName__c)
        //ExternalAccountLayoutSetting__mdt externalAccountLayoutSetting = [SELECT LayoutName__c FROM ExternalAccountLayoutSetting__mdt LIMIT 1];
        String pageLayout = 'Unknown'; // externalAccountLayoutSetting.LayoutName__c;
        String recordTypeName = '';
        String recordTypeId = '';
        String sObjectId = '';
        String sObjectName = '';
        String query = '';
    
        // Get the record type id of the external record
        sObjectName = recordId.getSObjectType().getDescribe().getName();  
        if (String.isNotBlank(sObjectName)) {
            query = 'SELECT RecordTypeId__c FROM ' + sObjectName + ' WHERE Id = :recordId LIMIT 1';
            sObject theRecord = Database.query(query);
            if (theRecord != null && String.isNotBlank((String)theRecord.get('RecordTypeId__c'))) {
                recordTypeId = (String)theRecord.get('RecordType.Id');
            }
        }

        // Get the record type id of the record.
        //Account theAccount = [SELECT Id, RecordType.Id FROM Account WHERE Id = :recordId];
        //String recordTypeId = theAccount.RecordType.Id;
    
        // Get the profile Id of current user.
        String profileId = UserInfo.getProfileId();

        // Retrieve Object Id via Object Name
        //
        // 03-17-2021 - SJC - Workaround for getSobjectType() returning error for external record ids of the form 'x0N-----------'
        // Note: In early development an external object record Id of the form 'x0N-------' was returning the standard
        // object rather than the external object's type via getSObjectType().  In recent testing this is now working (returns
        // external object type)).
        // 
        /*
        if (String.isNotBlank(recordId) && String.valueOf(recordId).length() >= 15) {
            if (String.valueOf(recordId).startsWithIgnoreCase('x01')) {
                sObjectName = 'ExternalAccount__x';
            } else {  
                sObjectName = recordId.getSObjectType().getDescribe().getName();  
            }
        }
        */
        system.debug('>>>'+sObjectName);
        
        // Get the internal Id for this sObjectName (so-called DurableId)
        List<EntityDefinition> theEntityDefinition = [SELECT DurableId FROM EntityDefinition WHERE QualifiedApiName = :sObjectName];
        if (theEntityDefinition.size() >= 1) {
            sObjectId = theEntityDefinition[0].DurableId;
        }
        system.debug('==='+sObjectId);
        
        if (String.isBlank(recordTypeId)) {
            // Query to retrieve the current users page layout (external or custom objects with no defined record types).
            query = 'SELECT Layout.FullName FROM ProfileLayout WHERE TableEnumOrId = \'' + sObjectId + '\' AND ProfileId = \'' + profileId + '\'';
        } else {
            // Query to retrieve the current users page layout (custom or standard objects with record types defined).
            query = 'SELECT Layout.FullName FROM ProfileLayout WHERE RecordTypeId = \'' + recordTypeId + '\' AND ProfileId = \'' + profileId + '\'';
        }

        String endpoint = 'callout:SFDCToolingAPI/services/data/v50.0/tooling/query?q=' + EncodingUtil.urlEncode(query, 'UTF-8');
        //String endpoint = URL.getSalesforceBaseUrl().toExternalForm() + '/services/data/v50.0/tooling/query/?q=' + EncodingUtil.urlEncode(query, 'UTF-8');
        
        System.debug('Tooling API Endpoint: ' + endpoint);
        System.debug('Tooling API Session: ' + UserInfo.getSessionID().substring(15));
        HttpRequest req = new HttpRequest();
        
        // Do not set header variables when using named credential, and insure named credential has 'Generate Authorization Header' enabled
        //req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionID());
        //req.setHeader('Content-Type', 'application/json');
    
        req.setEndpoint(endpoint);
        req.setMethod('GET');

        System.debug(req);
    
        Http h = new Http();

        // Set default page if Tooling API fails.
        String responseBody = '{"size" : 1, "done" : true, "records" : [ {"Layout" : {"FullName" : "' + pageLayout + '"} } ]}';

        // Call the tooling API if not called from Test classes.
        if (!Test.isRunningTest()) {
            // Call the tooling API
            HttpResponse res = h.send(req);
            System.debug('Tooling API Status Code: ' + res.getStatusCode());
            System.debug('Tooling API Response: ' + res.getBody());
            while (res.getStatusCode() == 302) {
                system.debug('>>new endpoint='+res.getHeader('Location'));
                req.setEndpoint('callout:SFDCToolingAPI' + res.getHeader('Location'));
                res = new Http().send(req); 
            }   
            if (res.getStatusCode() == 200) {
                responseBody = res.getBody();
            }      
        } 
        
        System.debug('Tooling API Response2: ' + responseBody);  
             
    
        // Parse the returned JSON
        Map<String, Object> mapQueryResult = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
    
        Integer size =  (Integer)mapQueryResult.get('size');
        Boolean done = (Boolean)mapQueryResult.get('done');

        // Retrieve the Page Layout name
        if (done == true && size == 1) {
            List<Object> listRecords = (List<Object>)mapQueryResult.get('records');
            Map<String, Object> mapFirstRecord = (Map<String, Object>)listRecords[0];
    
            Map<String, Object> mapLayout =   (Map<String, Object>)mapFirstRecord.get('Layout');
            pageLayout = (String)mapLayout.get('FullName');            
        }
    
        return pageLayout;        
    }
    


    // Inner class to hold field label and value.
    public class Field {
        @AuraEnabled
        public String label {get; set;}
        @AuraEnabled
        public Integer fldNumber {get; set;}

        // The datatype of this field
        @AuraEnabled
        public String type {get; set;}
        @AuraEnabled
        public Object value {get; set;}

        // If this field is a Lookup, lookupNameValue has the value from Name field of the child object.
        @AuraEnabled
        public Object lookupNameValue {get; set;}

        public Field(String label, Integer fldNumber, String type, Object value, Object lookupNameValue) {
          this.label = label;
          this.fldNumber = fldNumber;
          this.type = type;
          this.value = value;
          this.lookupNameValue = lookupNameValue;
        }
    }

    

    // Inner class to hold a Section and its fields.
    public class Section {
        @AuraEnabled
        public String name {get; set;}
        @AuraEnabled
        public Integer secNumber {get; set;}
        @AuraEnabled
        public List<Field> fields {get; set;}

        public Section(String name, Integer secNumber) {
          this.name = name;
          this.secNumber = secNumber;
          this.fields = new List<Field>();
        }
    }
}
