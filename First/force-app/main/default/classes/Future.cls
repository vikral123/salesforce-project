public class Future {
    @future
    public static void updateRecords() {

        List<Account> accounts = [
            SELECT Id, Name
            FROM Account
            WHERE Industry = 'Banking'
        ];

        for (Account acc : accounts) {
            acc.Description = 'hlw vikram how are you';
        }

        if (!accounts.isEmpty()) {
            update accounts;
        }
    }
}