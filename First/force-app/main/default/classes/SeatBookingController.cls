public with sharing class SeatBookingController {

    @AuraEnabled(cacheable=true)
    public static List<Floor__c> getFloors() {
        return [
            SELECT Id, Name
            FROM Floor__c
            ORDER BY Name ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<AggregateResult> getFloorWiseStatus() {
        return [
            SELECT Floor__r.Name floorName, Status__c status, COUNT(Id) total
            FROM Seat__c
            GROUP BY Floor__r.Name, Status__c
            ORDER BY Floor__r.Name ASC
        ];
    }

    @AuraEnabled
    public static List<Seat__c> getSeats(Id floorId) {

        List<Seat__c> seats = [
            SELECT Id,
                   Name,
                   Status__c,
                   Customer_Name__c,
                   Booked_By__c,
                   Booked_By__r.Name
            FROM Seat__c
            WHERE Floor__c = :floorId
        ];

        seats.sort(new SeatNameComparator());

        return seats;
    }

    public class SeatNameComparator implements Comparator<Seat__c> {
        public Integer compare(Seat__c a, Seat__c b) {
            Integer numA = extractNumber(a.Name);
            Integer numB = extractNumber(b.Name);

            if (numA != numB) {
                return numA - numB;
            }
            return a.Name.compareTo(b.Name);
        }

        private Integer extractNumber(String name) {
            String digitsOnly = name.replaceAll('[^0-9]', '');
            if (String.isBlank(digitsOnly)) {
                return 0;
            }
            return Integer.valueOf(digitsOnly);
        }
    }

    @AuraEnabled(cacheable=true)
    public static Integer getFloorSeatCount(Id floorId) {
        return [
            SELECT COUNT()
            FROM Seat__c
            WHERE Floor__c = :floorId
        ];
    }

    @AuraEnabled
    public static Boolean isSeatAvailable(Id seatId) {
        return [
            SELECT Status__c
            FROM Seat__c
            WHERE Id = :seatId
            LIMIT 1
        ].Status__c != 'Booked';
    }

    @AuraEnabled
    public static String bookSeat(Id seatId, String customerName, String email, String aadhaar) {

        if (String.isBlank(customerName)) {
            throw new AuraHandledException('Customer Name is required');
        }
        customerName = customerName.trim();
        if (customerName.length() < 3 || customerName.length() > 30) {
            throw new AuraHandledException('Customer Name must be between 3 and 50 characters.');
        }
        if (!Pattern.matches('^[A-Za-z ]+$', customerName)) {
            throw new AuraHandledException('Customer Name can contain only letters and spaces.');
        }
        if (String.isBlank(email)) {
            throw new AuraHandledException('Email is required');
        }
        email = email.trim();
        if (!Pattern.matches('^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$', email)) {
            throw new AuraHandledException('Please enter a valid email address.');
        }
        if (String.isBlank(aadhaar)) {
            throw new AuraHandledException('Aadhaar Number is required.');
        }
        aadhaar = aadhaar.trim();
        if (!Pattern.matches('^[0-9]{12}$', aadhaar)) {
            throw new AuraHandledException('Aadhaar Number must be exactly 12 digits.');
        }

        try {
            Seat__c seat = [
                SELECT Id,
                       Floor__c,
                       Status__c,
                       Customer_Name__c,
                       Booked_By__c
                FROM Seat__c
                WHERE Id = :seatId
                FOR UPDATE
            ];

            if (seat.Status__c == 'Booked') {
                return 'ALREADY_BOOKED';
            }

            // Poore floor ki saari seats ko lock karo, taaki parallel bookings
            // stale (purana) count na dekh paayein — race condition se bachne ke liye
            List<Seat__c> floorSeats = [
                SELECT Id, Status__c
                FROM Seat__c
                WHERE Floor__c = :seat.Floor__c
                FOR UPDATE
            ];

            Integer bookedCount = 0;
            for (Seat__c s : floorSeats) {
                if (s.Status__c == 'Booked') {
                    bookedCount++;
                }
            }

            System.debug('Selected Seat Id : ' + seat.Id);
            System.debug('Selected Floor Id : ' + seat.Floor__c);
            System.debug('Booked Count : ' + bookedCount);

            if (bookedCount >= 10) {
                throw new AuraHandledException(
                    'This floor has already reached the maximum booking limit of 10 seats.'
                );
            }

            seat.Status__c = 'Booked';
            seat.Booked_By__c = UserInfo.getUserId();
            seat.Customer_Name__c = customerName;
            update seat;

            List<Contact> contacts = [
                SELECT Id
                FROM Contact
                WHERE Email = :email
                LIMIT 1
            ];

            Contact con;

            if (contacts.isEmpty()) {
                con = new Contact(
                    LastName = customerName,
                    Email = email
                );
                insert con;
            } else {
                con = contacts[0];
            }

            Booking__c booking = new Booking__c(
                Seat__c = seatId,
                 Floor__c = seat.Floor__c,
                User__c = UserInfo.getUserId(),
                Contact__c = con.Id,
                CustomerName__c = customerName,
                Email__c = email,
                Aadhaar__c = aadhaar,
                Status__c = 'Active',
                Booking_Date__c = Date.today()
            );

            insert booking;

            sendBookingEmail(con.Id, booking.Id);

            return 'SUCCESS';

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Booking failed: ' + e.getMessage()
            );
        }
    }

    @AuraEnabled(cacheable=true)
    public static Booking__c getBookingDetails(Id seatId) {

        List<Booking__c> bookings = [
            SELECT Id,
                   Contact__c,
                   Status__c,
                   Email__c,
                   Aadhaar__c,
                   CustomerName__c
            FROM Booking__c
            WHERE Seat__c = :seatId
            AND Status__c = 'Active'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        return bookings.isEmpty() ? null : bookings[0];
    }

    @AuraEnabled
    public static String cancelBooking(Id seatId) {

        try {

            Seat__c seat = [
                SELECT Id,
                       Status__c,
                       Customer_Name__c,
                       Booked_By__c
                FROM Seat__c
                WHERE Id = :seatId
                LIMIT 1
            ];

            List<Booking__c> bookings = [
                SELECT Id,
                       Contact__c,
                       Status__c,
                       Email__c
                FROM Booking__c
                WHERE Seat__c = :seatId
                AND Status__c = 'Active'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            seat.Status__c = 'Available';
            seat.Customer_Name__c = null;
            seat.Booked_By__c = null;
            update seat;

            if (!bookings.isEmpty()) {

                Booking__c booking = bookings[0];
                booking.Status__c = 'Cancelled';
                update booking;

                if (booking.Contact__c != null) {
                    sendCancelEmail(booking.Contact__c, booking.Id);
                }
            }

            return 'SUCCESS';

        } catch (Exception e) {
            throw new AuraHandledException('Cancellation failed: ' + e.getMessage());
        }
    }

    private static void sendBookingEmail(Id contactId, Id bookingId) {

        List<EmailTemplate> templates = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = 'Seat_Booking_Confirmation_1782994399447'
            LIMIT 1
        ];

        if (templates.isEmpty()) {
            return;
        }

        try {

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTemplateId(templates[0].Id);
            mail.setTargetObjectId(contactId);
            mail.setWhatId(bookingId);
            mail.setSaveAsActivity(false);
            Messaging.sendEmail(
                new List<Messaging.SingleEmailMessage>{ mail }
            );

        } catch (Exception e) {
            System.debug('Booking Email Error : ' + e.getMessage());
        }
    }

    private static void sendCancelEmail(Id contactId, Id bookingId) {

        List<EmailTemplate> templates = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = 'Seat_Booking_Cancelled_1782994738331'
            LIMIT 1
        ];

        if (templates.isEmpty()) {
            return;
        }

        try {

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTemplateId(templates[0].Id);
            mail.setTargetObjectId(contactId);
            mail.setWhatId(bookingId);
            mail.setSaveAsActivity(false);

            Messaging.sendEmail(
                new List<Messaging.SingleEmailMessage>{ mail }
            );

        } catch (Exception e) {
            System.debug('Cancel Email Error : ' + e.getMessage());
        }
    }
}