public with sharing class VOCController {
    @AuraEnabled(cacheable=true scope='global')
    public static List<Sales_Product__c> searchCustomers(String phoneNumber, Integer pageNumber) {
        String phoneNumberPattern = '%' + phoneNumber + '%';
        Integer pageSize = 5;
        Integer offset = (pageNumber - 1) * pageSize;
    
        List<Sales_Product__c> queryResult = [SELECT Id, Contact__c, CustomerNumber__c, Email__c, Product_Name_Text__c, Serial_Number__c, Account__c, Purchased_Date_Time_c__c
                                              FROM Sales_Product__c
                                              WHERE CustomerNumber__c LIKE :phoneNumberPattern AND Status__c = '판매'
                                              ORDER BY CustomerNumber__c, Contact__c ASC, Purchased_Date_Time_c__c DESC, Account__c
                                              LIMIT :pageSize OFFSET :offset];
                                              
        return queryResult;
    }
    

    // @AuraEnabled(cacheable=true scope='global')
    // public static List<Contact_Products__c> searchContactProductsByOrderCode(String searchTerm) {
    //     searchTerm = searchTerm.trim();
    //     if (searchTerm == '') {
    //         return getAllPurchasedContactProducts();
    //     }
        
    //     searchTerm = '%' + searchTerm + '%';

    //     return [SELECT Id, Name,  Product_Name_Text__c, Contact__r.name, Order_Code__c 
    //             FROM Contact_Products__c 
    //             WHERE Status__c = 'Purchased'
    //             AND Is_SaleProduct_Created__c = false
    //             AND Order_Code__c LIKE :searchTerm 
    //             WITH SECURITY_ENFORCED
    //             ORDER BY CreatedDate DESC ];
    // }
}