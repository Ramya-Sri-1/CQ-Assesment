global class PartToProductBatch implements Database.Batchable<SObject>, Schedulable {

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, Part_Number__c, Product__c 
            FROM SQX_Part__c 
            WHERE Active_c__c = true AND Product__c = null
        ]);
    }

    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        Map<String, Product2> productMap = new Map<String, Product2>();
        List<Product2> toInsert = new List<Product2>();
        List<SQX_Part__c> toUpdate = new List<SQX_Part__c>();
        Map<String, SQX_Part__c> partsNeedingNewProduct = new Map<String, SQX_Part__c>();

        Set<String> keys = new Set<String>();
        for (SQX_Part__c part : (List<SQX_Part__c>)scope) {
            keys.add(part.Name + '||' + part.Part_Number__c);
        }

        List<Product2> existing = [SELECT Id, Name, ProductCode FROM Product2];
        for (Product2 prod : existing) {
            String key = prod.Name + '||' + prod.ProductCode;
            productMap.put(key, prod);
        }

        for (SQX_Part__c part : (List<SQX_Part__c>)scope) {
            String key = part.Name + '||' + part.Part_Number__c;
            if (productMap.containsKey(key)) {
                part.Product__c = productMap.get(key).Id;
            } else {
                Product2 newProd = new Product2(
                    Name = part.Name,
                    ProductCode = part.Part_Number__c,
                    IsActive = true
                );
                toInsert.add(newProd);
                productMap.put(key, newProd);
                partsNeedingNewProduct.put(key, part);
            }
            toUpdate.add(part);
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;

            for (Product2 prod : toInsert) {
                String key = prod.Name + '||' + prod.ProductCode;
                if (partsNeedingNewProduct.containsKey(key)) {
                    partsNeedingNewProduct.get(key).Product__c = prod.Id;
                }
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    global void finish(Database.BatchableContext bc) {}

    global void execute(SchedulableContext sc) {
        // Check if the running user has the "CQ Product Admin" permission set
        Id currentUserId = UserInfo.getUserId();
        String permSetName = 'CQ_Product_Admin'; // API name (not label!)

        List<PermissionSetAssignment> psaList = [
            SELECT Id 
            FROM PermissionSetAssignment 
            WHERE AssigneeId = :currentUserId 
            AND PermissionSet.Name = :permSetName
        ];

        if (psaList.isEmpty()) {
            System.debug('Permission denied: User does not have CQ Product Admin permission set');
            return; // Don't run the batch
        }

        Database.executeBatch(new PartToProductBatch(), 50);
    }
}