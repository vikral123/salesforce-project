import { LightningElement } from 'lwc';

export default class MyComponent extends LightningElement {

    firstName = '';
    lastName = '';

    submittedFirstName = '';
    submittedLastName = '';

    showData = false;

    handleFirstname(event) {
        this.firstName= event.target.value;
    }

    handleLastName(event) {
        this.lastName = event.target.value;
    }

    handleSubmit() {
        this.submittedName = this.firstName +  this.lastName;
        this.showData = true;
    }
}