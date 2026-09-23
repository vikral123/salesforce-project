({
    submitForm : function(component, event, helper) {

        var userName = component.get("v.userName");
        var email = component.get("v.email");

        alert(
            "User Name : " + userName +
            "\nEmail : " + email
        );

    }
})