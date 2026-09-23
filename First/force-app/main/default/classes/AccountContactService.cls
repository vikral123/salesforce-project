public with sharing class AccountContactService {

    @AuraEnabled
    public static void createAccountAndContact(
        String accName,
        String conName,
        String conEmail,
        String zip,
        String city,
        String state
    ) {
        if (String.isBlank(accName)) {
            throw new AuraHandledException('Account Name is required.');
        }

        if (String.isBlank(conName)) {
            throw new AuraHandledException('Contact Name is required.');
        }

        if (String.isBlank(conEmail)) {
            throw new AuraHandledException('Email is required.');
        }

        if (String.isBlank(zip)) {
            throw new AuraHandledException('Zip Code is required.');
        }

        if (String.isBlank(city)) {
            throw new AuraHandledException('City is required.');
        }

        if (String.isBlank(state)) {
            throw new AuraHandledException('State is required.');
        }

        // Email Format Validation
        Pattern emailPattern = Pattern.compile(
            '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'
        );

        if (!emailPattern.matcher(conEmail).matches()) {
            throw new AuraHandledException('Please enter a valid email address.');
        }

        Account acc = new Account(
            Name = accName
        );
        insert acc;

    
        Contact con = new Contact(
            LastName = conName,
            Email = conEmail,
            AccountId = acc.Id,
            MailingPostalCode = zip,
            City__c = city,
            State__c = state
        );

        System.debug('Contact Before Insert = ' + con);

        insert con;

        // Verify values after insert
        Contact c = [
            SELECT City__c, State__c
            FROM Contact
            WHERE Id = :con.Id
        ];

        System.debug('Saved City: ' + c.City__c);
        System.debug('Saved State: ' + c.State__c);
    }
}