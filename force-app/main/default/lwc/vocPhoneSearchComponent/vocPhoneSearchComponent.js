import { LightningElement, track, wire } from 'lwc';
import searchContactsByPhoneNumber from '@salesforce/apex/ContactController.searchContactsByPhoneNumber';

export default class ContactLookup extends LightningElement {
    @track searchPhoneNumber = '';
    @track contacts = [];

    handleSearchPhoneNumberChange(event) {
        this.searchPhoneNumber = event.target.value;
        this.searchContacts();
    }

    @wire(searchContactsByPhoneNumber, { phoneNumber: '$searchPhoneNumber' })
    wiredContacts({ error, data }) {
        if (data) {
            this.contacts = data;
        } else if (error) {
            console.error('Error fetching contacts:', error);
        }
    }
}