public with sharing class ConsultantTriggerHandler {
    public static void updateConsultationCount(List<Consultant__c> triggerNew) {
        
        Set<Id> contactIds = new Set<Id>();
        Set<String> storeNames = new Set<String>();
        List<Contact> contactsToUpdate = new List<Contact>();
        List<Account> accountsToUpdate = new List<Account>();
        
        for (Consultant__c c : triggerNew) {
            contactIds.add(c.CustomerName__c);
            storeNames.add(c.Account__c);
        }

        Integer consultantCount = [SELECT COUNT() 
                                   FROM Consultant__c 
                                   WHERE CustomerName__c = :contactIds];
        
        for(Id contactId : contactIds){
                contactsToUpdate.add(new Contact(
                Id = contactId, 
                Consultation_Count__c = consultantCount));
            }
            
        ///////////이하 판매점 관련/////////////
            
        Map<String, Integer> storeNameToConsultantCount = new Map<String, Integer>();
        for (AggregateResult aggregate : [SELECT StoreName__c, COUNT(Id) cnt
                                           FROM Consultant__c 
                                           WHERE StoreName__c IN :storeNames
                                           GROUP BY StoreName__c]) {
            storeNameToConsultantCount.put((String)aggregate.get('StoreName__c'), (Integer)aggregate.get('cnt'));
        }
        
        for (String storeName : storeNames) {
            Integer accountConsultantCount = storeNameToConsultantCount.containsKey(storeName) ? storeNameToConsultantCount.get(storeName) : 0;
        
            accountsToUpdate.add(new Account(Name = storeName, 
                                             Total_Consultation_Count__c = accountConsultantCount));
        }
            


        
        if (!contactsToUpdate.isEmpty()) {
            update contactsToUpdate;
        }
            
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }
}