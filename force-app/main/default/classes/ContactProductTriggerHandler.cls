public with sharing class ContactProductTriggerHandler {
    // REQ-11
    public static void UpdatePurchaseStoreAndDateInContact(List<Contact_Products__c> triggerNew) {
        List<Contact> contactProductToUpdate = new List<Contact>(); 
        Set<Id> contactIds = new Set<Id>();
        
        // Contact_Products__c에서 Contact__c 필드를 추출하여 contactIds 세트에 추가
        for (Contact_Products__c c : triggerNew) {
            contactIds.add(c.Contact__c);
        }
        // Contact에서 고객 제품 주문과 일치하는 id, 이름, 고객 유형, 첫 구매 매장, 최근 구매 매장을 조회해서 contactList에 담아줌
        List<Contact> contactList = [SELECT Id, Name, Type__c, First_Purchase_Store__c, Latest_Purchase_Store__c
                                    FROM Contact
                                    WHERE Id IN :contactIds];
            Map<Id, Contact_Products__c> contactProductMap = new Map<Id, Contact_Products__c>();
            for (Contact_Products__c cp : triggerNew) {
                contactProductMap.put(cp.Contact__c, cp); // 마지막 Contact_Products__c 레코드로 맵 업데이트
            }
            // Latest_Purchase_Date__c = contact의 최근구매일 , Order_Date_Time__c = 고객제품주문(Date/Time)
            // 예제: DateTime 타입의 값을 Date 타입으로 변환하여 할당
    
            for(Contact c : contactList) {
                Contact_Products__c cp = contactProductMap.get(c.Id);
                if(c.First_Purchase_Store__c == null && cp != null) {
                    //첫 구매상점 , 최근 구매상점 업데이트
                    c.First_Purchase_Store__c = cp.Account__c;
                    c.Latest_Purchase_Store__c = cp.Account__c;
                    // Order_Date_Time__c (DateTime 타입)에서 Date 객체로 변환
                    DateTime dtValue = cp.Order_Date_Time__c; // DateTime 값을 추출
                    Date dateValue = dtValue.date(); // DateTime에서 Date로 변환
                    c.Latest_Purchase_Date__c = dateValue; // 최근 구매일 수정
                    contactProductToUpdate.add(c);
                } else if (cp != null) {
                    //최근 구매상점 업데이트
                    c.Latest_Purchase_Store__c = cp.Account__c;
                    // Order_Date_Time__c (DateTime 타입)에서 Date 객체로 변환
                    DateTime dtValue = cp.Order_Date_Time__c; // DateTime 값을 추출
                    Date dateValue = dtValue.date(); // DateTime에서 Date로 변환
                    c.Latest_Purchase_Date__c = dateValue; // 최근 구매일 수정
                    contactProductToUpdate.add(c);
                }
            }
        // 구매상점 변화 발생 시 업데이트하여 넣어줌
        if(contactProductToUpdate.size() > 0) {
            update contactProductToUpdate;
        }
    }
    
    
    //고객제품주문 생성 후 판매가 없으면 생성해주고, 있으면 값을 업데이트 해주는 method 
    public static void insertAndUpdateSale(List<Contact_Products__c> contactProduct) {
        List<String> ProductNameList = new List<String>();
        String ProductName = '';
        List<Sale__c> saleToInsert = new List<Sale__c>();
        List<Sale__c> saleToUpdate = new List<Sale__c>();
        Set<String> SalesCode = new Set<String>(); 
        List<Contact_Products__c> contactProductToUpdate = new List<Contact_Products__c>();

        // ContactProductController에서 판매코드를 담아오는 메서드를 불러와서 판매코드 담아줌
        SalesCode = ContactProductController.getSalesCode(contactProduct); 
        
        // 고객제품주문코드와 주문제품들의 제품명을 담아줌
        Set<String> OrderCode = new Set<String>();
        for(Contact_Products__c cp : contactProduct){
            OrderCode.add(cp.Order_Code__c);
            ProductNameList.add(cp.Product_Name_Text__c);
        }

        // 제품이 여러개면 붙여서 출력하게 해줌 
        for(String pd : ProductNameList){
            ProductName += pd + '\n';
         }
       
         // 고객제품주문코드로 총 합을 불러오는 쿼리
        AggregateResult[] TotalPriceResults = [SELECT SUM(Total_Product_Price__c) totalPrice 
                                            FROM Contact_Products__c 
                                            WHERE Order_Code__c IN :OrderCode];
        Decimal TotalPrice = (Decimal)TotalPriceResults[0].get('totalPrice'); 
         
        // 판매코드가 비어있을 때
        if(SalesCode.isEmpty()){
            for(Contact_Products__c cp : [SELECT Account__c, Contact__c, Order_Date_Time__c, Discount_Percent__c, Order_Code__c, Product_Name_Text__c
                                        FROM Contact_Products__c 
                                        WHERE Order_Code__c = :OrderCode]){                                            
                // 할인율이 없을 떄
                if(cp.Discount_Percent__c == null){
                    cp.Discount_Percent__c = 0; 
                }
                Decimal DiscountAmount = (TotalPrice * cp.Discount_Percent__c / 100); 
                // 최종가격
                Decimal FinalPrice = TotalPrice - DiscountAmount; 
                // 판매코드가(판매레코드가) 주문코드로부터 부여되서 생성되지 않았을 때 
                if (!SalesCode.contains('S'+ cp.Order_Code__c)) {
                    // 판매 레코드 생성
                    Sale__c sc = new Sale__c();
                    sc.Account__c = cp.Account__c;
                    sc.Customer__c = cp.Contact__c;
                    sc.Date_of_sale__c = cp.Order_Date_Time__c;
                    sc.List_of_Purchased_Items__c = ProductName;
                    sc.Total_Price__c = TotalPrice.intValue();
                    sc.Discount_Value__c = DiscountAmount.intValue();
                    sc.Discount_Percent__c = cp.Discount_Percent__c;
                    sc.Final_Price__c = FinalPrice.intValue();
                    sc.Sales_Code__c = 'S'+ cp.Order_Code__c;
                    SalesCode.add(sc.Sales_Code__c);
                    saleToInsert.add(sc);
                }
            }     
        // 판매코드가 있을 때
        } else if(!SalesCode.isEmpty()){ 
            // 여러개의 제품을 주문했을 경우 추가할 제품명을 담아줌
            String AdditionalProductName = '';
            // 생성된 판매 레코드가 있을 경우 아이디를 가져오는 메서드
            Set<Id> SaleId = ContactProductController.getSaleId(contactProduct);
            Id salesId;
            TotalPrice = (Decimal)TotalPriceResults[0].get('totalPrice'); 
            
             // 추가한 제품명들을 이어서 담아줌
            for(String pd : ProductNameList){
                AdditionalProductName += pd + '\n';
            }


            // 업데이트할 판매 레코드를 불러오는 쿼리 
            for(Sale__c scToUpdate : [SELECT Id, Total_Price__c, List_of_Purchased_Items__c, Discount_Value__c, Final_Price__c, Discount_Percent__c
                                    FROM Sale__c 
                                    WHERE Id IN :SaleId]){
                // 기존의 값에서 최종적으로 더해지는 값들로 업데이트 
                Decimal DiscountAmount = (TotalPrice * scToUpdate.Discount_Percent__c / 100); 
                Decimal FinalPrice = TotalPrice - DiscountAmount;
                scToUpdate.Total_Price__c = TotalPrice.intValue();
                scToUpdate.Discount_Value__c = DiscountAmount.intValue();
                scToUpdate.Final_Price__c = FinalPrice;
                scToUpdate.List_of_Purchased_Items__c += '\n' + AdditionalProductName;  
                salesId = scToUpdate.Id;
                saleToUpdate.add(scToUpdate);
            }

            for(Contact_Products__c cp : [SELECT Id, Name, Sale__c
                                          FROM Contact_Products__c  
                                          WHERE Order_Code__c IN :OrderCode]){
                if(cp.Sale__c == null){
                   cp.Sale__c = salesId;
                   contactProductToUpdate.add(cp);
                }                    
            }
        }
        
        // 생성할 판매레코드가 생성 
        if (!saleToInsert.isEmpty()) {
            insert saleToInsert;
        }
        
        // 업데이트할 판매레코드가 있으면 업데이트
        if (!saleToUpdate.isEmpty()) {
            update saleToUpdate;
        }

        // 업데이트할 판매레코드가 있으면 업데이트
        if (!contactProductToUpdate.isEmpty()) {
            update contactProductToUpdate;
        }
    }
    
        public static void InsertAccountSalesInformationSale(List<Contact_Products__c> contactProducts) {
            // Account ID 수집
            Set<Id> accountIds = new Set<Id>();
            for (Contact_Products__c cp : contactProducts) {
                accountIds.add(cp.Account__c);
            }
            // 현재 날짜와 비교할 Date 변수 설정
            Integer year = Date.today().year();
            Integer month = Date.today().month();
            Integer daily = Date.today().day();
            // 필요한 Account 레코드 조회
            Map<Id, Account> accountMap = new Map<Id, Account>([
                SELECT Id, Total_Sales__c, Annual_Sales__c, Monthly_Sales__c, Daily_Sales__c,
                LastYearlyUpdate__c,LastMonthlyUpdate__c,LastDailyUpdate__c,
                Total_General_Device_Sales__c,Total_Laptop_Sales__c
                FROM Account
                WHERE Id IN :accountIds
                ]);
                // Set<Id> accountIds = new Set<Id>();
            for (Contact_Products__c cp : contactProducts) {
                accountIds.add(cp.Account__c);
            }
                // 각 Account의 총 판매액 업데이트 + 초기화
            for (Contact_Products__c cp : contactProducts) {
                if(cp.Status__c == 'Purchased') {
                    if (accountMap.containsKey(cp.Account__c)) {
                        Account acc = accountMap.get(cp.Account__c);
                        // 총매출액 구하기
                        if(acc.Total_Sales__c == null) {
                            acc.Total_Sales__c = cp.Total_Purchase__c;
                        } else {
                            acc.Total_Sales__c += cp.Total_Purchase__c;
                        }
                        //주변기기 매출 총액
                        if(acc.Total_General_Device_Sales__c == null) {
                            acc.Total_General_Device_Sales__c = cp.Total_Purchase_of_General_Devices__c;
                        } else {
                            acc.Total_General_Device_Sales__c += cp.Total_Purchase_of_General_Devices__c;
                        }
                        //노트북 매출 총액
                        if(acc.Total_Laptop_Sales__c == null) {
                            acc.Total_Laptop_Sales__c = cp.Total_Purchase_of_Laptops__c;
                        } else {
                            acc.Total_Laptop_Sales__c += cp.Total_Purchase_of_Laptops__c;
                        }
                        //날짜가 null || 다르면 값을 갱신 매출액 초기화
                        if(acc.LastYearlyUpdate__c == null || acc.LastYearlyUpdate__c != year) {
                            acc.Annual_Sales__c = cp.Total_Purchase__c;
                            acc.LastYearlyUpdate__c = year;
                        } else {
                            acc.Annual_Sales__c += cp.Total_Purchase__c;
                        }
                        if(acc.LastMonthlyUpdate__c == null || acc.LastMonthlyUpdate__c != month) {
                            acc.Monthly_Sales__c = cp.Total_Purchase__c;
                            acc.LastMonthlyUpdate__c = month;
                        } else {
                            acc.Monthly_Sales__c += cp.Total_Purchase__c;
                        }
                        if(acc.LastDailyUpdate__c == null || acc.LastDailyUpdate__c != daily) {
                            acc.Daily_Sales__c = cp.Total_Purchase__c;
                            acc.LastDailyUpdate__c = daily;
                        } else {
                            acc.Daily_Sales__c += cp.Total_Purchase__c;
                        }
                    }
                }
                // cp.Total_Purchase__c = 0;
            }
            
            // 업데이트된 Account 레코드 저장
            update accountMap.values();
        }

        public static void UpdateAccountSalesInformationRefund(List<Contact_Products__c> contactProducts) {
            // Account ID 수집
            Set<Id> accountIds = new Set<Id>();
            for (Contact_Products__c cp : contactProducts) {
                accountIds.add(cp.Account__c);
            }
            // 현재 날짜와 비교할 Date 변수 설정
            Integer year = Date.today().year();
            Integer month = Date.today().month();
            Integer daily = Date.today().day();
            // 필요한 Account 레코드 조회
            Map<Id, Account> accountMap = new Map<Id, Account>([
                SELECT Id, Total_Sales__c, Annual_Sales__c, Monthly_Sales__c, Daily_Sales__c,
                LastYearlyUpdate__c,LastMonthlyUpdate__c,LastDailyUpdate__c,
                Total_General_Device_Sales__c,Total_Laptop_Sales__c
                FROM Account
                WHERE Id IN :accountIds
                ]);

                // 각 Account의 총 판매액 업데이트 + 초기화
            for (Contact_Products__c cp : contactProducts) {
                if (accountMap.containsKey(cp.Account__c)) {
                    Account acc = accountMap.get(cp.Account__c);
                }
                DateTime orderDateTime = cp.Order_Date_Time__c;
                Date orderDate = orderDateTime.Date();
                Integer orderInt = orderDate.day();
                if(cp.Status__c == 'Refunded') { // 제품이 '구매'일 경우 값 변동 X
                    Account acc = accountMap.get(cp.Account__c);
                    // 총매출액 빼기
                        acc.Total_Sales__c -= cp.Total_Purchase__c;
                    //주변기기 매출 뺴기
                        acc.Total_General_Device_Sales__c -= cp.Total_Purchase_of_General_Devices__c;
                    //노트북 매출 빼기
                        acc.Total_Laptop_Sales__c -= cp.Total_Purchase_of_Laptops__c;
                    // 날짜별 매출 빼기
                    if(acc.LastYearlyUpdate__c == year) {
                        acc.Annual_Sales__c -= cp.Total_Purchase__c;
                    }
                    if(acc.LastMonthlyUpdate__c == month && acc.LastYearlyUpdate__c == year) {
                        acc.Monthly_Sales__c -= cp.Total_Purchase__c;
                    }
                    if(orderInt == daily && acc.LastMonthlyUpdate__c == month && acc.LastYearlyUpdate__c == year) {
                        acc.Daily_Sales__c -= cp.Total_Purchase__c;
                    }
                }
            }
            
            // 업데이트된 Account 레코드 저장
            update accountMap.values();
        }
}