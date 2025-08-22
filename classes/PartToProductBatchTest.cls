@isTest
private class PartToProductBatchTest {

    @isTest
    static void testPartToProductBatch() {
        // Get System Admin profile
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        // Create test user with unique username
        User admin = new User(
            Alias = 'tadmin',
            Email = 'testadmin@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'uniqueuser_' + DateTime.now().getTime() + '@test.com'
        );
        insert admin;

        System.runAs(admin) {
            // Case 1: Matching Product exists
            Product2 existingProd = new Product2(
                Name = 'ExistingPart',
                ProductCode = 'EX001',
                IsActive = true
            );
            insert existingProd;

            SQX_Part__c matchingPart = new SQX_Part__c(
                Name = 'ExistingPart',
                Part_Number__c = 'EX001',
                Active_c__c = true
            );
            insert matchingPart;

            // Case 2: No matching product – should create new product
            SQX_Part__c newPart = new SQX_Part__c(
                Name = 'NewPart',
                Part_Number__c = 'NP001',
                Active_c__c = true
            );
            insert newPart;

            Test.startTest();
            Database.executeBatch(new PartToProductBatch(), 50);
            Test.stopTest();

            // Re-query updated parts
            matchingPart = [SELECT Product__c FROM SQX_Part__c WHERE Id = :matchingPart.Id];
            newPart = [SELECT Product__c FROM SQX_Part__c WHERE Id = :newPart.Id];

            System.assertNotEquals(null, matchingPart.Product__c, 'Matching product should be linked');
            System.assertNotEquals(null, newPart.Product__c, 'New product should be created and linked');

            // Optionally validate the created product
            Product2 createdProduct = [SELECT Name, ProductCode FROM Product2 WHERE Id = :newPart.Product__c];
            System.assertEquals('NewPart', createdProduct.Name);
            System.assertEquals('NP001', createdProduct.ProductCode);
        }
    }

    @isTest
    static void testSchedulerExecutesBatch() {
        Test.startTest();
        String cronExp = '0 0 6 * * ?'; // 6 AM GMT
        System.schedule('Daily PartToProduct Job', cronExp, new PartToProductBatch());
        Test.stopTest();

        // No assertion needed; this ensures scheduler code is covered
    }
}