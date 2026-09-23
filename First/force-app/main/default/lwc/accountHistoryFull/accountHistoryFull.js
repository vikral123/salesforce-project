import { LightningElement, wire } from 'lwc';
import getAllHistory from '@salesforce/apex/AccountHistoryController.getAllHistory';

export default class AccountHistoryFull extends LightningElement {

    historyRecords = [];
    error;
    isLoading = true;

    @wire(getAllHistory)
    wiredHistory({ data, error }) {
        this.isLoading = false;

        if (data) {
            this.historyRecords = data.map(record => ({
                id: record.Id,
                account: record.Account?.Name || '-',
                field: this.formatFieldName(record.Field),
                oldValue: this.formatValue(record.OldValue),
                newValue: this.formatValue(record.NewValue),
                changedBy: record.CreatedBy?.Name || '-',
                date: this.formatDate(record.CreatedDate)
            }));
            this.error = undefined;
        } else if (error) {
            console.error('Account History Error:', error);
            this.error = error;
            this.historyRecords = [];
        }
    }

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

    formatValue(value) {
        return (value === null || value === undefined || value === '') ? '-' : String(value);
    }

    formatDate(dateValue) {
        if (!dateValue) return '-';
        return new Intl.DateTimeFormat('en-US', {
            year: 'numeric', month: 'short', day: '2-digit'
        }).format(new Date(dateValue));
    }

    get hasRecords() {
        return this.historyRecords.length > 0;
    }
}