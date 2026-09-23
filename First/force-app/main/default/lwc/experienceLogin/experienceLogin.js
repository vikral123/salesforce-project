import { LightningElement } from 'lwc';
import loginUser from '@salesforce/apex/ExperienceLoginController.loginUser';

export default class ExperienceLogin extends LightningElement {

    username = '';
    password = '';
    errorMessage = '';
    isLoading = false;

    handleUsername(event) {
        this.username = event.target.value;
    }

    handlePassword(event) {
        this.password = event.target.value;
    }

    login() {

        this.errorMessage = '';
        this.isLoading = true;

        console.log('Username : ' + this.username);

        loginUser({
            username: this.username,
            password: this.password
        })
        .then(result => {

            console.log('Returned URL : ', result);

            if (result === 'INVALID') {

                this.errorMessage = 'Invalid Username or Password';
                this.isLoading = false;
                return;
            }

            window.location.replace(result);

        })
        .catch(error => {

            console.error(error);

            this.isLoading = false;

            if (error.body && error.body.message) {
                this.errorMessage = error.body.message;
            } else {
                this.errorMessage = 'Something went wrong.';
            }
        });
    }
}