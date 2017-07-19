//
//  UniversalLoginViewController.swift
//  Owncloud iOs Client
//
//  Created by Noelia Alvarez on 21/06/2017.
//
//

/*
 Copyright (C) 2017, ownCloud GmbH.
 This code is covered by the GNU Public License Version 3.
 For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 You should have received a copy of this license
 along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 */

import Foundation

struct K {
    struct segueId {
        static let segueToWebLoginView = "segueToWebLoginView"
    }
    
    struct unwindId {
        static let unwindToMainLoginView = "unwindToMainLoginView"
    }
    
    struct vcId {
        static let vcIdWebViewLogin = "WebViewLoginViewController"
    }
    
}

//@objc public enum LoginMode: Int {
//    case Create
//    case Update
//    case Expire
//    case Migrate
//}


//TODO: check if needed use the notification relaunchErrorCredentialFilesNotification from edit account mode
//TODO: check if is needed property hidesBottomBarWhenPushed in this class to use with edit and add account modes
//TODO: check if need to call delegate #pragma mark - AddAccountDelegate- (void) refreshTable  in settings after add account
//TODO: check if need to setBarForCancelForLoadingFromModal in this class
//TODO: check if neet to use the notification LoginViewControllerRotate from login view (- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration)

@objc public class UniversalLoginViewController: UIViewController, UITextFieldDelegate, SSODelegate, ManageNetworkErrorsDelegate {
 
// MARK: IBOutlets
    
    @IBOutlet var imageViewLogo: UIImageView!
    @IBOutlet var textFieldURL: UITextField!
    @IBOutlet var buttonConnect: UIButton!
    @IBOutlet var buttonHelpLink: UIButton!
    @IBOutlet var buttonReconnection: UIButton!
    @IBOutlet var imageUrlFooter: UIImageView!
    @IBOutlet var labelUrlFooter: UILabel!
    
    var urlNormalized: String!
    var validatedServerURL: String!
    var allAvailableAuthMethods = [AuthenticationMethod]()
    var authMethodToLogin: AuthenticationMethod!
    var authCodeReceived = ""
    var manageNetworkErrors: ManageNetworkErrors!
    var loginMode: LoginMode!
    
    let serverURLNormalizer: ServerURLNormalizer = ServerURLNormalizer()
    let getPublicInfoFromServerJob: GetPublicInfoFromServerJob = GetPublicInfoFromServerJob()
    
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.manageNetworkErrors = ManageNetworkErrors()
        self.manageNetworkErrors.delegate = self
        textFieldURL.delegate = self;
        self.buttonConnect.isEnabled = false
        // Do any additional setup after loading the view.
        
        //set branding style
        print("Init login with loginMode: \(loginMode.rawValue) (0=Create,1=Update,2=Expire,3=Migrate)")
    }
    
    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setLoginMode(loginMode: LoginMode) {
        self.loginMode = loginMode
    }
    
// MARK: checkUrl
    
    func checkCurrentUrl() {
        
        if let inputURL = textFieldURL.text {
            self.urlNormalized = serverURLNormalizer.normalize(serverURL: inputURL)

            // get public infor from server
            getPublicInfoFromServerJob.start(serverURL: self.urlNormalized, withCompletion: { (validatedURL: String?, _ serverAuthenticationMethods: Array<Any>?, _ error: Error?, _ httpStatusCode: NSInteger) in
                
                if error != nil {
                    //TODO: show error
                    print ("error detecting authentication methods")
                    
                } else if validatedURL != nil {

                    self.validatedServerURL = validatedURL;
                    self.allAvailableAuthMethods = serverAuthenticationMethods as! [AuthenticationMethod]
                    
                    self.authMethodToLogin = DetectAuthenticationMethod().getAuthMethodToLoginFrom(availableAuthMethods: self.allAvailableAuthMethods)
                    
                    if (self.authMethodToLogin != .NONE) {
                        self.buttonConnect.isEnabled = true
                    } else {
                        self.buttonConnect.isEnabled = false
                        //TODO show error
                    }
                    
                } else {
                    self.manageNetworkErrors.returnErrorMessage(withHttpStatusCode: httpStatusCode, andError: nil)
                }
            })
        }
    }
    
    
// MARK: start log in auth
    
    func startAuthenticationWith(authMethod: AuthenticationMethod) {
        
        switch authMethod {

        case .SAML_WEB_SSO:
            navigateToSAMLLoginView();
            break

        case .BEARER_TOKEN:
            navigateToOAuthLoginView();
            break

        case .BASIC_HTTP_AUTH:
            //TODO
            break

        default:
            //TODO: show footer Error
            break
        }

    }
    
    func openWebViewLogin() {
        
    }
    
    func navigateToSAMLLoginView() {

        //Grant main thread
        DispatchQueue.main.async {
            print("_showSSOLoginScreen_ url: %@", self.urlNormalized);
            
            //New SSO WebView controller
            let ssoViewController: SSOViewController = SSOViewController(nibName: "SSOViewController", bundle: nil);
            ssoViewController.urlString = self.urlNormalized;
            ssoViewController.delegate = self;

            //present it
            ssoViewController.navigate(from: self);
        }
    }
    
    func navigateToOAuthLoginView() {
        performSegue(withIdentifier: K.segueId.segueToWebLoginView, sender: self)
    }
    

// MARK: ManageNetworkError delegate
    
    public func errorLogin() {
        //TOOD: SHow error in url footer
    }
    
// MARK: SSODelegate implementation
    
    /**
     * This delegate method is called from SSOViewController when the user
     * successfully logs-in.
     *
     * @param cookieString -> NSString      Cookies in last state of the SSO WebView , including SSO cookie & OC session cookie.
     * @param samlUserName -> NSString      Username.
     *
     */

    public func setCookieForSSO(_ cookieString: String!, andSamlUserName samlUserName: String!) {
        
        print("BACK with cookieString %@ and samlUserName %@", cookieString, samlUserName);
        
        if cookieString == nil || cookieString == "" {
            // TODO show error
            return;
        }
        
        if samlUserName == nil || samlUserName == "" {
            // TODO show error NSLocalizedString(@"saml_server_does_not_give_user_id", nil)
            return
        }
        
        let userCredDto: CredentialsDto = CredentialsDto()
        userCredDto.userName = samlUserName
        userCredDto.accessToken = cookieString
        userCredDto.authenticationMethod = self.authMethodToLogin.rawValue
        
        validateCredentialsAndCreateNewAccount(credentials: userCredDto);
        
    }
    
//MARK: Manage network errors delegate
    public func showError(_ message: String!) {
        DispatchQueue.main.async {
            self.imageUrlFooter.isHidden = false
            self.imageUrlFooter.image = UIImage(named: "CredentialsError.png")!
            self.labelUrlFooter.text = message
        }
    }

    
// MARK: textField delegate
    
    public func textFieldDidEndEditing(_ textField: UITextField) {

        self.checkCurrentUrl()
        
    }


// MARK: IBActions
    
    @IBAction func reconnectionButtonTapped(_ sender: Any) {
        self.checkCurrentUrl()
    }
    
    
    @IBAction func connectButtonTapped(_ sender: Any) {
        
        self.startAuthenticationWith(authMethod: self.authMethodToLogin)
        
    }
    
    
    @IBAction func helpLinkButtonTapped(_ sender: Any) {
        //open web view help
        
    }
    
    @IBAction func unwindToMainLoginView(segue:UIStoryboardSegue) {
        if let sourceViewController = segue.source as? WebLoginViewController {
            let webVC: WebLoginViewController = sourceViewController
            if !(webVC.authCode).isEmpty {
                self.authCodeReceived = webVC.authCode
                
                let urlToGetAuthData = OauthAuthentication().oauthUrlToGetTokenWith(serverPath: self.urlNormalized)
                OauthAuthentication().getAuthDataBy(url: urlToGetAuthData, authCode: self.authCodeReceived, withCompletion: { ( userCredDto: CredentialsDto?, error: String?) in
                
                    if let userCredentials = userCredDto {
                        
                        self.validateCredentialsAndCreateNewAccount(credentials: userCredentials);
                        
                    } else {
                        // TODO show error?
                    }
                })
            }
        }
    }
    

// MARK: segue
    override public func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if(segue.identifier == K.segueId.segueToWebLoginView) {
            
            let nextViewController = (segue.destination as! WebLoginViewController)
            nextViewController.serverPath = self.urlNormalized
        }
    }
    
    
// MARK: 'private' methods
    
    func validateCredentialsAndCreateNewAccount(credentials: CredentialsDto) {
        //get list of files in root to check session validty, if ok store new account
        let urlToGetRootFiles = URL (string: UtilsUrls.getFullRemoteServerPathWithWebDav(byNormalizedUrl: self.urlNormalized) )
        
        DetectListOfFiles().getListOfFiles(url: urlToGetRootFiles!, credentials: credentials,
                                           withCompletion: { (_ errorHttp: NSInteger?,_ error: Error?, _ listOfFileDtos: [FileDto]? ) in
                                            
                                            if (listOfFileDtos != nil && !((listOfFileDtos?.isEmpty)!)) {
                                                
                                                let user: UserDto = UserDto()
                                                user.url = self.urlNormalized
                                                user.username = credentials.userName
                                                
                                                user.ssl = self.urlNormalized.hasPrefix("https")
                                                user.activeaccount = true
                                                user.urlRedirected = (UIApplication.shared.delegate as! AppDelegate).urlServerRedirected
                                                user.predefinedUrl = k_default_url_server
                                                
                                                ManageAccounts().storeAccountOfUser(user, withCredentials: credentials)
                                                
                                                ManageFiles().storeListOfFiles(listOfFileDtos!, forFileId: 0)
                                                
                                                //Generate the app interface
                                                (UIApplication.shared.delegate as! AppDelegate).generateAppInterface(fromLoginScreen: true)
                                                
                                            } else {
                                                
                                                self.manageNetworkErrors.returnErrorMessage(withHttpStatusCode: errorHttp!, andError: error)
                                            }
        })
        
    }
    
}
