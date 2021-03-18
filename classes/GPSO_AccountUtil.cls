public class GPSO_AccountUtil {
        @AuraEnabled(cacheable=true)
        public static ExternalAccount__x getExternalAccount(Id accountId) {
            SObjectType externalAccountType = Schema.getGlobalDescribe().get('ExternalAccount__x');
            Map<String,Schema.SObjectField> mfields = externalAccountType.getDescribe().fields.getMap();

            String fieldList = '';
            String queryString = 'Select ';
            for (String fieldName : mfields.keySet()) {
                if (fieldList.length() > 0) fieldList += ',';
                fieldList += fieldname;
            }
            queryString += fieldList + ' From ExternalAccount__x Where Id = ' + '\'' + accountId + '\'' + ' WITH SECURITY_ENFORCED';

            List <sObject> extAccounts = Database.query(queryString);
            // [Select Id, Name__c, Phone__c, BillingStreet__c, BillingCity__c, BillingState__c From ExternalAccount__x Where Id = :accountId];
            if (extAccounts.size() >= 1) {
                ExternalAccount__x theExternalAccount = (ExternalAccount__x)extAccounts[0];
                system.debug('ext acc='+theExternalAccount);
                return theExternalAccount;  
            } else {
                ExternalAccount__x emptyAccount = new ExternalAccount__x(Name__c='External Account Not Found', Phone__c='800-555-1212', BillingStreet__c='N/A');
                system.debug('empty acc='+emptyAccount);
                return emptyAccount;
            }
        }
    }