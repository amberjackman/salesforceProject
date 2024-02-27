public with sharing class ConsultantTriggerHandler {
    public static void updateConsultationCount(List<Consultant__c> triggerNew) {
        Set<Id> contactIds = new Set<Id>();

        for (Consultant__c c : triggerNew) {
            contactIds.add(c.CustomerName__c);
        }
        List<Contact> contactsToUpdate = new List<Contact>();
        Integer consultantCount = [SELECT COUNT() 
                                   FROM Consultant__c 
                                   WHERE CustomerName__c = :contactIds];

        for(Id contactId : contactIds){
            contactsToUpdate.add(new Contact(
                Id = contactId, 
                Consultation_Count__c = consultantCount));
        }

        if (!contactsToUpdate.isEmpty()) {
            update contactsToUpdate;
        }


///////////이하 판매점 관련/////////////

        Map<Id, Integer> consultantCounts = new Map<Id, Integer>();

        for (AggregateResult aggregate : [
            SELECT CustomerName__c, COUNT(Id) consultantCount
            FROM Consultant__c
            WHERE CustomerName__c IN :contactIds
            GROUP BY CustomerName__c
        ]) {
            Id contactId = (Id)aggregate.get('CustomerName__c');
            Integer count = (Integer)aggregate.get('consultantCount');
            consultantCounts.put(contactId, count);
        }
        
        Set<String> storeNames = new Set<String>();

        for (Consultant__c c : triggerNew) {
            storeNames.add(c.CustomerName__r.StoreName__c);
        }
             
        List<Account> accountsToUpdate = new List<Account>();
        for (String storeName : storeNames) {
            accountsToUpdate.add(new Account(
                StoreName__c = storeName,
                Total_Consultation_Count__c = consultantCounts.get(storeName)
            ));
        }

        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }
}