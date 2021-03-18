// accountWrapper.js
import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import getExternalAccount from '@salesforce/apex/GPSO_AccountUtil.getExternalAccount';
import getSectionsAndFields from '@salesforce/apex/GPSO_ExternalObjectUtilities.getsObjectFields';

const FIELDS = [
    'Account.Name',
    'Account.External_Account_Id__c'
];
const EXTFIELDS = [
    'ExternalAccount__x.Name__c',
    'ExternalAccount__x.Phone__c',
    'ExternalAccount__x.BillingStreet__c'
];

export default class AccountWrapper extends LightningElement {
    @api recordId;
    @api objectApiName; 
    @track account = null;
    @track externalAccount = null;
    @track externalAccountId = null;
    extAcct = null;
    data = null;
    error = null;
    sectionsAndFields = null;
    
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    processRecord({data, error}) {
        if (data) {
            this.account = data;
            this.externalAccountId = data.fields.External_Account_Id__c.value; 
            getSectionsAndFields ({recordId: this.externalAccountId})
            .then(result => {
                this.sectionsAndFields = result;
            })
            getExternalAccount ({accountId: this.externalAccountId})
            .then(result => {
                this.externalAccount = result; 
                this.extAcct = JSON.parse(JSON.stringify(this.externalAccount));
            })
        }
    }

    //@wire(getExternalAccount, {accountId: '$externalAccountId'})
    //processExternal({data, error}) {
    //    if (data) {
    //        this.externalAccount = data;
    //        this.extAcct = JSON.parse(JSON.stringify(this.externalAccount));
    //    }
    //}
    
    //externalAccountId = this.account.data.fields.External_Account_Id__c.value; 
    //@wire(getExternalAccount, { accountId: '$account.data.fields.External_Account_Id__c.value' }) 
    //externalAccount;  

    get name() {
        if (this.account) return this.account.fields.Name.value;
    }

    get billingstreet() {
        if (this.extAcct) return this.extAcct.BillingStreet__c;   
    }
}