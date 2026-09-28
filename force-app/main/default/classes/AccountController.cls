public  class AccountController {   
    public static List<Account> getAccounts() {
        return [SELECT Id, Name FROM Account limit 5];
    }
}