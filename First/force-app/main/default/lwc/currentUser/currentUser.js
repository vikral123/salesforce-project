import { LightningElement, wire } from 'lwc';
import USER_ID from '@salesforce/user/Id';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import NAME_FIELD from '@salesforce/schema/User.Name';

import getHighPriorityCaseCount from '@salesforce/apex/CurrentUserController.getHighPriorityCaseCount';

const FIELDS = [NAME_FIELD];

export default class CurrentUser extends LightningElement {

    userId = USER_ID;

    highPriorityCaseCount = 0;

    // Get logged-in user's name
    @wire(getRecord, {
        recordId: '$userId',
        fields: FIELDS
    })
    user;

    get userName() {
        if (this.user.data) {
            return getFieldValue(this.user.data, NAME_FIELD);
        }

        return '';
    }

   
    @wire(getHighPriorityCaseCount, {
        userId: '$userId'
    })
    wiredHighPriorityCases({ data, error }) {

        if (data !== undefined) {
            this.highPriorityCaseCount = data;
        }

        if (error) {
            console.error('Error:', error);
            this.highPriorityCaseCount = 0;
        }
    }
}