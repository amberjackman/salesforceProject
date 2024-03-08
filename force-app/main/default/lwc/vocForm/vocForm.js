import { LightningElement, track } from 'lwc';
import searchCustomers from '@salesforce/apex/VOCController.searchCustomers';

const columns = [
    { label: '고객이름', fieldName: 'Contact__c' },
    { label: '전화번호', fieldName: 'CustomerNumber__c' },
    { label: '이메일', fieldName: 'Email__c' },
    { label: '구매제품', fieldName: 'Product_Name_Text__c' },
    { label: '시리얼번호', fieldName: 'Serial_Number__c' },
    { label: '판매점', fieldName: 'Account__c' },
    { label: '판매날짜', fieldName: 'Purchased_Date_Time_c__c' },
];

export default class CustomerSearch extends LightningElement {
    @track phoneNumberPattern = '';
    @track searchResults;
    @track selectedCustomer;
    @track error;
    columns = columns;

    handlePhoneChange(event) {
        this.phoneNumberPattern = event.target.value;
        this.error = ''; // 입력값이 변경될 때마다 에러 메시지를 초기화합니다.
    }

    searchCustomers() {
        if (this.phoneNumberPattern.length < 3) {
            this.error = '3자리 이상의 전화번호를 입력하세요.';
            this.searchResults = null; // 검색 결과를 초기화합니다.
            return;
        }

        searchCustomers({ phoneNumber: this.phoneNumberPattern })
            .then(result => {
                this.searchResults = result;
                this.error = ''; // 검색이 성공하면 에러 메시지를 초기화합니다.
            })
            .catch(error => {
                console.error('Error:', error);
                this.searchResults = null; // 검색 결과를 초기화합니다.
                this.error = '검색 중 오류가 발생했습니다.';
            });
    }

    closeResults() {
        this.searchResults = null;
    }

    handleRowAction(event) {
        const selectedRow = event.detail.row;
        this.selectedCustomer = selectedRow;
    }
}