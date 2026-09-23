public class ContactUpdateQueueable implements Queueable {

    public void execute(QueueableContext context) {

        List<Contact> getallcontacts = [
            SELECT Id, Name, Email
            FROM Contact
            WHERE Email != null
        ];

        for (Contact con : getallcontacts) {
            con.Description = 'this is vikram bora section';
        }

        if (!getallcontacts.isEmpty()) {
            update getallcontacts;
        }
    }
}