import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCityState from '@salesforce/apex/ZipCodeLookupService.getCityState';
import createRecords from '@salesforce/apex/AccountContactService.createAccountAndContact';

export default class AccountContactForm extends LightningElement {
    accountName = '';
    contactName = '';
    email = '';
    zipCode = '';
    city = '';
    state = '';
    errorMessage = '';

    handleChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
    }

    async handleZipBlur() {
        if (!this.zipCode) return;
        try {
            const result = await getCityState({ zipCode: this.zipCode });
            console.log('Result:', JSON.stringify(result));
            if (result.error) {
                this.errorMessage = result.error;
                this.city = '';
                this.state = '';
            } else {
                this.errorMessage = '';
                this.city = result.city;
                this.state = result.state;
            }
        } catch (e) {
            this.errorMessage = 'Error fetching zip code details';
        }
    }
async handleSubmit() {
    try {

        // Agar city/state abhi tak blank hai to pehle fetch kar lo
        if (!this.city || !this.state) {
            const result = await getCityState({ zipCode: this.zipCode });

            if (result.error) {
                this.errorMessage = result.error;
                return;
            }

            this.city = result.city;
            this.state = result.state;
        }

        console.log('City:', this.city);
        console.log('State:', this.state);

        await createRecords({
            accName: this.accountName,
            conName: this.contactName,
            conEmail: this.email,
            zip: this.zipCode,
            city: this.city,
            state: this.state
        });

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Account & Contact created successfully',
                variant: 'success'
            })
        );

    } catch (e) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: e.body ? e.body.message : 'Something went wrong',
                variant: 'error'
            })
        );
    }
}
    // async handleSubmit() {
    //     try {
    //         await createRecords({
    //             accName: this.accountName,
    //             conName: this.contactName,
    //             conEmail: this.email,
    //             zip: this.zipCode,
    //             city: this.city,
    //             state: this.state
    //         });
    //         this.dispatchEvent(new ShowToastEvent({
    //             title: 'Success',
    //             message: 'Account & Contact created successfully',
    //             variant: 'success'
    //         }));
    //     } catch (e) {
    //         this.dispatchEvent(new ShowToastEvent({
    //             title: 'Error',
    //             message: e.body ? e.body.message : 'Something went wrong',
    //             variant: 'error'
    //         }));
    //     }
    // }
}