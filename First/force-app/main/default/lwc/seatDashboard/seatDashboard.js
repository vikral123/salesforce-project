import { LightningElement, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { refreshApex } from '@salesforce/apex';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import SEAT_BOOKED_CHANNEL from '@salesforce/messageChannel/SeatBookedChannel__c';
import chartJs from '@salesforce/resourceUrl/chartjs';
import getFloorWiseStatus from '@salesforce/apex/SeatBookingController.getFloorWiseStatus';

export default class SeatDashboard extends LightningElement {

    chart;
    chartJsInitialized = false;
    floorData = [];
    wiredResult;
    subscription;

    @wire(MessageContext)
    messageContext;

    @wire(getFloorWiseStatus)
    wiredData(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.floorData = data;
            this.drawChart();
        } else if (error) {
            console.error(error);
        }
    }

    connectedCallback() {
        this.subscription = subscribe(
            this.messageContext,
            SEAT_BOOKED_CHANNEL,
            () => this.refreshData()
        );
    }

    disconnectedCallback() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    refreshData() {
        refreshApex(this.wiredResult);   
    }

    renderedCallback() {
        if (this.chartJsInitialized) return;

        this.chartJsInitialized = true;

        loadScript(this, chartJs)
            .then(() => this.drawChart())
            .catch(error => console.error(error));
    }

    drawChart() {
        if (!window.Chart || !this.floorData.length) return;

        const canvas = this.template.querySelector('canvas');
        if (!canvas) return;

        const ctx = canvas.getContext('2d');

        if (this.chart) {
            this.chart.destroy();
        }

        this.chart = new window.Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: this.floorData.map(i => `${i.floorName} - ${i.status || 'NA'}`),
                datasets: [{
                    data: this.floorData.map(i => i.total),
                    backgroundColor: [
                        '#66BB6A', '#F44336', '#FF8A65',
                        '#AB47BC', '#26C6DA', '#EF5350',
                        '#FFA726', '#8BC34A'
                    ],
                    borderColor: '#fff',
                    borderWidth: 2
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                cutout: '60%',
                plugins: {
                    legend: {
                        position: 'bottom'
                    },
                    title: {
                        display: true,
                        text: 'Floor Wise Seat Distribution'
                    }
                }
            }
        });
    }
}