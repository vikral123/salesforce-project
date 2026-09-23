public without sharing class ExperienceLoginController {

    @AuraEnabled
    public static String loginUser(String username, String password) {

        try {

            String targetPath = '/employeeportal/';

            List<User> users = [
                SELECT Id, Profile.Name
                FROM User
                WHERE Username = :username
                LIMIT 1
            ];

            System.debug('Users Found : ' + users.size());

            if (!users.isEmpty()) {

                String profileName = users[0].Profile.Name;

                System.debug('Profile : ' + profileName);

                if (profileName == 'Customer Portal Manager Custom') {

                    targetPath = '/employeeportal/admin-dashboard';

                } else if (profileName == 'Customer Community User') {

                    targetPath = '/employeeportal/customer-dashboard';
                }
            }

            System.debug('Target Path : ' + targetPath);

            PageReference pageRef = Site.login(username, password, targetPath);

            if (pageRef == null) {
                return 'INVALID';
            }

            return pageRef.getUrl();

        } catch (Exception e) {

            System.debug(e);

            throw new AuraHandledException(e.getMessage());
        }
    }
}