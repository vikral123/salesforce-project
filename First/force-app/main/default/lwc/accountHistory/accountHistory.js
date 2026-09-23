import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import getLatestHistory
    from '@salesforce/apex/AccountHistoryController.getLatestHistory';

export default class AccountHistory extends NavigationMixin(LightningElement) {
    historyRecords = [];
    error;
    isLoading = true;
    @wire(getLatestHistory)
    wiredHistory({ data, error }) {
      this.isLoading = false;
        if (data) {
            this.historyRecords = data.map(record => {
                return {

                    id: record.Id,

                    account:
                        record.Account?.Name || '-',

                    field:
                        this.formatFieldName(
                            record.Field
                        ),

                    oldValue:
                        this.formatValue(
                            record.OldValue
                        ),

                    newValue:
                        this.formatValue(
                            record.NewValue
                        ),

                    changedBy:
                        record.CreatedBy?.Name || '-',

                    date:
                        this.formatDate(
                            record.CreatedDate
                        )

                };

            });

            this.error = undefined;

        } else if (error) {

            console.error(
                'Account History Error:',
                error
            );

            this.error = error;

            this.historyRecords = [];
        }
    }


    // Convert Salesforce Field API/history names
    // into user-friendly labels
    formatFieldName(field) {

        const fieldNames = {

            Name: 'Account Name',

            Owner: 'Account Owner',

            Type: 'Account Type',

            Industry: 'Industry',

            Phone: 'Phone',

            Rating: 'Rating'

        };

        return fieldNames[field] || field;
    }


    // Handle empty Old/New values
    formatValue(value) {

        if (
            value === null ||
            value === undefined ||
            value === ''
        ) {
            return '-';
        }

        return String(value);
    }


    // Format Salesforce DateTime
    formatDate(dateValue) {

        if (!dateValue) {
            return '-';
        }

        return new Intl.DateTimeFormat(
            'en-US',
            {
                year: 'numeric',
                month: 'short',
                day: '2-digit'
            }
        ).format(
            new Date(dateValue)
        );
    }


    get hasRecords() {

        return this.historyRecords.length > 0;

    }


    handleViewMore() {

        this[NavigationMixin.Navigate]({

            type: 'standard__navItemPage',

            attributes: {

                apiName: 'accountHistoryFull'

            }

        });

    }

}