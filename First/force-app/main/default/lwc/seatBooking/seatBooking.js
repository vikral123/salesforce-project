import { LightningElement, track, wire } from 'lwc';
import getFloorSeatCount from '@salesforce/apex/SeatBookingController.getFloorSeatCount';
import getFloors from '@salesforce/apex/SeatBookingController.getFloors';
import getBookingDetails from '@salesforce/apex/SeatBookingController.getBookingDetails';
import getSeats from '@salesforce/apex/SeatBookingController.getSeats';
import cancelBookingApex from '@salesforce/apex/SeatBookingController.cancelBooking';
import bookSeat from '@salesforce/apex/SeatBookingController.bookSeat';
import isSeatAvailable from '@salesforce/apex/SeatBookingController.isSeatAvailable';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { publish, MessageContext } from 'lightning/messageService';
import SEAT_BOOKED_CHANNEL from '@salesforce/messageChannel/SeatBookedChannel__c';

export default class SeatBooking extends LightningElement {
@track showBookedDetailsModal = false;

   @track bookedCustomerName = '';
@track bookedCustomerEmail = '';
@track bookedCustomerAadhaar = '';
    @track selectedFloor;
    @track seatCount = 0;
    @track seats = [];

    @track floorOptions = [];

    @track selectedSeatId;

    @track selectedSeatName;

    @track showConfirmModal = false;

    @track showDetailsModal = false;

    @track customerName = '';

    @track email = '';

    @track aadhaar = '';
    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.loadFloors();
    }

    loadFloors() {

        getFloors()

            .then(result => {
                this.floorOptions = result.map(floor => ({
                    label:floor.Name,
                    value: floor.Id

                }));

            })
            .catch(error => {
                console.error(error);
            });
    }
    loadSeatCount() {
        getFloorSeatCount({ floorId: this.selectedFloor })
            .then(result => {
                this.seatCount = result;
            })
            .catch(error => {
                console.error(error);
            });
    }
    handleSearch(event) {

        const searchKey = event.target.value.toLowerCase();

        this.seats = this.allSeats.filter(seat => {

            const customerName = seat.customerName
                ? seat.customerName.toLowerCase()
                : '';

            return customerName.includes(searchKey);
            

        });

    }
    handleFloorChange(event) {

        this.selectedFloor = event.detail.value;

        this.loadSeats();
        this.loadSeatCount();
    }

    loadSeats() {

        getSeats({ floorId: this.selectedFloor })

            .then(result => {

                console.log('SEATS => ', JSON.stringify(result));

                this.allSeats = result
                    .filter(seat => seat.status__c)
                    .map(seat => {

                        const status = seat.status__c;
                        return {
                            Id: seat.Id,
                            Name: seat.Name,
                            customerName: seat.Customer_Name__c,
                            status__c: status,
                            isBooked: status === 'Booked' || status === 'Reserved',
                              buttonLabel:
        status === 'Booked'
            ? 'View Detail'
            : 'Click to Booking',

                            statusLabel:
                                status === 'Booked'
                                    ? 'Already Booked'
                                    : status === 'Reserved'
                                        ? 'Reserved'
                                        : 'Available',

                            badgeClass:
                                status === 'Booked'
                                    ? 'badge booked-badge'
                                    : status === 'Reserved'
                                        ? 'badge reserved-badge'
                                        : 'badge available-badge',

                            uiClass:
                                status === 'Booked'
                                    ? 'seat-card booked'
                                    : status === 'Reserved'
                                        ? 'seat-card reserved'
                                        : 'seat-card available'
                        };

                    });

                this.seats = [...this.allSeats];
            })
            .catch(error => {
                console.error(error);
            });

    }
  handleSeatClick(event) {
    const seatId = event.currentTarget.dataset.id;
    console.log('Seat Id:', seatId);

    const seat = this.seats.find(s => s.Id === seatId);
    console.log('Seat:', JSON.stringify(seat));

    if (!seat) {
        console.log('Seat not found');
        return;
    }

    if (seat.isBooked) {

        console.log('Booked seat clicked');

        this.selectedSeatId = seat.Id;
        this.selectedSeatName = seat.Name;

        getBookingDetails({ seatId: seat.Id })
            .then(result => {

                console.log('Apex Result:', JSON.stringify(result));

                if (result) {

               this.bookedCustomerName = result.CustomerName__c || '';
           this.bookedCustomerEmail = result.Email__c || '';
            this.bookedCustomerAadhaar = result.Aadhaar__c || '';

                    this.showBookedDetailsModal = true;

                    console.log('Modal Opened');
                } else {
                    console.log('Result is null');
                }

            })
            .catch(error => {

                console.log('Apex Error:', JSON.stringify(error));

                this.showToast(
                    'Error',
                    error.body.message,
                    'error'
                );

            });

        return;
    }

    this.selectedSeatId = seat.Id;
    this.selectedSeatName = seat.Name;
    this.showConfirmModal = true;
}
    confirmSeat() {

        isSeatAvailable({

            seatId: this.selectedSeatId

        })
            .then(result => {

                if (!result) {

                    this.showConfirmModal = false;

                    this.showToast(

                        'Error',

                        'Seat already booked',

                        'error'

                    );

                    this.loadSeats();

                    return;

                }

                this.showConfirmModal = false;

                this.showDetailsModal = true;

            });

    }
cancelBooking() {

    cancelBookingApex({
        seatId: this.selectedSeatId
    })
    .then(result => {

        if(result === 'SUCCESS'){

            this.showToast(
                'Success',
                'Booking cancelled successfully',
                'success'
            );
            publish(this.messageContext, SEAT_BOOKED_CHANNEL, { action: 'cancelled' });

            this.closeModal();

            this.loadSeats();
            this.loadSeatCount();
        }

    })
    .catch(error => {

        this.showToast(
            'Error',
            error.body.message,
            'error'
        );

    });

}
 closeModal() {

    this.showConfirmModal = false;

    this.showDetailsModal = false;

    this.showBookedDetailsModal = false;
}

    handleName(event) {

        this.customerName = event.target.value;

    }

    handleEmail(event) {

        this.email = event.target.value;

    }

    handleAadhaar(event) {

        this.aadhaar = event.target.value;

    }

    completeBooking() {
        const inputs = this.template.querySelectorAll('lightning-input');

        let isValid = true;

        inputs.forEach(input => {
            input.reportValidity();
            if (!input.checkValidity()) {
                isValid = false;
            }
        });

        if (!isValid) {
            return;
        }

        bookSeat({
            seatId: this.selectedSeatId,
            customerName: this.customerName,
            email: this.email,
            aadhaar: this.aadhaar,
            
        })
            .then(result => {

                if (result === 'SUCCESS') {

                    this.seats = [...this.seats.map(seat => {
                        if (seat.Id === this.selectedSeatId) {
                            return {
                                ...seat,
                                status__c: 'Booked',
                                isBooked: true,
                                statusLabel: 'Already Booked',
                                badgeClass: 'badge booked-badge',
                                uiClass: 'seat-card booked'
                            };
                        }
                        return seat;
                    })];

                    console.log('UPDATED UI => ', JSON.stringify(this.seats));

                    this.showToast(
                        'Success',
                        'Seat booked successfully',
                        'success'
                    );

                    
                    publish(this.messageContext, SEAT_BOOKED_CHANNEL, { action: 'booked' });

                    this.closeModal();

                    this.loadSeats();
                    this.loadSeatCount();
                }
            })
           .catch(error => {
    this.dispatchEvent(
        new ShowToastEvent({
            title: 'Validation Error',
            message: error.body.message,
            variant: 'error'
        })
    );
});
    }
    showToast(title, message, variant) {

        this.dispatchEvent(

            new ShowToastEvent({
                title,
                message,
                variant

            })

        );

    }

}