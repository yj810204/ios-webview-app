//
//  ViewController.swift
//  theyouthdream
//
//  Created by 정영남 on 2022/05/03.
//

import UIKit
import WebKit
import SafariServices
import FirebaseMessaging
import CoreLocation

extension CALayer {
    func addBorder(_ arr_edge: [UIRectEdge], color: UIColor, width: CGFloat) {
        for edge in arr_edge {
            let border = CALayer()
            switch edge {
            case UIRectEdge.top:
                border.frame = CGRect.init(x: 0, y: 0, width: frame.width, height: width)
                break
            case UIRectEdge.bottom:
                border.frame = CGRect.init(x: 0, y: frame.height - width, width: frame.width, height: width)
                break
            case UIRectEdge.left:
                border.frame = CGRect.init(x: 0, y: 0, width: width, height: frame.height)
                break
            case UIRectEdge.right:
                border.frame = CGRect.init(x: frame.width - width, y: 0, width: width, height: frame.height)
                break
            default:
                break
            }
            border.backgroundColor = color.cgColor
            self.addSublayer(border)
        }
    }
}

extension ViewController: WKDownloadDelegate {
    
    @available(iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }
    
    @available(iOS 14.5, *)
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
     
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(suggestedFilename)
        print("File URL: \(fileURL)")
        
        let documentInteractionController = UIDocumentInteractionController(url: fileURL)
        documentInteractionController.delegate = self
        documentInteractionController.presentPreview(animated: true)
        
        completionHandler(fileURL)
    }
    
    @available(iOS 14.5, *)
    func downloadDidFinish(_ download: WKDownload) {
        print("File Download Success")
        
    }
    
    @available(iOS 14.5, *)
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        print(error)
    }
}

extension ViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
}

class ViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate, UIScrollViewDelegate, CLLocationManagerDelegate {
    
    let locationManager = CLLocationManager()
    
    let alignUrl = "https://howtattoo.co.kr/"
//    let alignUrl = "https://rlms.snctek.com/"
    var refreshControl = UIRefreshControl()
    var browser_title = ""
    var pop_browser_title = ""
    var browser_url = ""
    var pop_browser_url = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        print("")
        print("===============================")
        print("[ViewController >> viewDidLoad() : 액티비티 메모리 로드 실시]")
        print("===============================")
        print("")
        
        // [웹뷰 호출 실시]
        //mainWebViewInit(_loadUrl: alignUrl + "index.php?mid=app&act=dispAppmgmtSplashScreenForIos", _type: "Splash") // get 방식, 라이믹스용 로딩화면
        //mainWebViewInit(_loadUrl: "", _type: "Splash")
        mainImageViewInit()
        subWebViewInit(_loadUrl: alignUrl, _type: "Main")
        
        NotificationCenter.default.addObserver(self, selector: #selector(dispFCMToken(notification:)), name: Notification.Name("FCMToken"), object: nil)
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        
        // 이미 권한이 있다면 즉시 요청
        let status = CLLocationManager.authorizationStatus()
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
    
    @objc func reloadWebView(_ sender: UIRefreshControl) {
        subWebView.reload()
        sender.endRefreshing()
    }
    
    @objc func dispFCMToken(notification: NSNotification) {
        guard let userInfo = notification.userInfo else {
            return
        }
        
        let url = URL(string: alignUrl)
        let domain = url?.host
        
        if let fcmToken = userInfo["token"] as? String {
            let cookie = HTTPCookie(properties: [
                .domain: domain!,
                .path: "/",
                .name: "device_token",
                .value: fcmToken,
                .secure: "TRUE",
                .expires: NSDate(timeIntervalSinceNow: 31556926)
            ])!
            subWebView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
            
            self.callHttpAsync(reqUrl: alignUrl + "modules/appmgmt/libs/deviceToken.php?device_token=" + fcmToken){(result, msg) in
                print("")
                print("====================================")
                print("[A_Main >> callHttpAsync() :: 비동기 http 통신 콜백 확인]")
                print("result :: ", result)
                print("msg :: ", msg)
                print("====================================")
                print("")
            }
            
        }
    }
    
    // [상태 창 높이값 구하기 실시 :: 배터리 표시 부분]
//    let statusBarHeight = UIApplication.shared.statusBarFrame.height + 15
    let statusBarHeight = UIApplication.shared.statusBarFrame.height
    
    // MARK: [인디게이터 변수 선언 실시 = 스토리보드 없이 동적으로 생성]
    private var activityIndicator = UIActivityIndicatorView()
    
    // MARK: [웹뷰 변수 선언 실시 = 스토리보드 없이 동적으로 생성]
    @IBOutlet weak var mainImageView: UIImageView!
    //@IBOutlet weak var mainWebView: WKWebView!
    @IBOutlet weak var subWebView: WKWebView!
    //private var mainWebView: WKWebView? = nil
    var popupWebView: WKWebView?
    
    // 위치 관련 UI 요소를 추가합니다
    private var locationStatusView: UIView?
    private var locationStatusLabel: UILabel?
    private var locationIndicator: UIActivityIndicatorView?
    
    // [ViewController 종료 시 호출되는 함수]
    deinit {
        // WKWebView Progress 퍼센트 가져오기 이벤트 제거
        //mainWebView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        subWebView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }
    
    // MARK: [인디게이터 설정]
    func setupActivityIndicator() {
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.style = .large
        activityIndicator.color = UIColor(red: 0.35, green: 0.31, blue: 0.32, alpha: 1.00)
        view.addSubview(activityIndicator)
    }
    
    func mainImageViewInit() {
        mainImageView.frame = CGRect.init(
            x:0,
            y:0,
            width: self.view.frame.width,
            height: self.view.frame.height
        )
        subWebView.addSubview(mainImageView)
        
        self.callHttpAsync(reqUrl: alignUrl + "modules/appmgmt/libs/appInfo_ios.php"){(result, msg) in
            print("")
            print("====================================")
            print("[A_Main >> callHttpAsync() :: 비동기 http 통신 콜백 확인]")
            print("result :: ", result)
            print("msg :: ", msg)
            print("====================================")
            print("")
            
            let jsonData = msg.data(using: .utf8)
            let json = try! JSONSerialization.jsonObject(with: jsonData!, options: []) as! [String : Any]
            
            //모듈에 설정값 불러오기
            let delay_time = json["delay_time"] as! String
            let bg_image = json["bg_image"] as! String
            let bg_name = json["bg_name"] as! String
            let app_use = json["app_use"] as! String
            let app_version = json["app_version"] as! String
            let update_title = json["update_title"] as! String
            let update_desc = json["update_desc"] as! String
            let app_update = json["app_update"] as! String
            let noti_use = json["noti_use"] as! String
            let noti_title = json["noti_title"] as! String
            let noti_desc = json["noti_desc"] as! String
            let app_btn = json["app_btn"] as! String
            let app_id = json["app_id"] as! String
            
            if(bg_image != "-99") {
                var tempImg : UIImage
                if let ImageData = try? Data(contentsOf: URL(string: self.alignUrl + bg_image)!) {
                    tempImg = UIImage(data: ImageData)!
                } else {
                    tempImg = UIImage(named: "loading_image.jpg")!
                }
                
                DispatchQueue.main.async {
                    self.mainImageView.image = tempImg
                }
            }
            
            if(app_use == "-1") {
                let alertController = UIAlertController(title: "알림", message: "앱 사용안함으로 설정되었습니다.\r\n앱을 종료합니다.", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "확인", style: .default, handler: { (action) in
                    UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        exit(0)
                    }
                }))
                //self.present(alertController, animated: true, completion: nil)
                DispatchQueue.main.async {
                    self.present(alertController, animated: true, completion: nil)
                }
            } else {
                if(app_version != "-99" && app_id != "-99" && app_update != "-99" && update_title != "-99" && update_desc != "-99") {
                    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
                    
                    if(app_version == appVersion) {
                        if(noti_use == "1") {
                            let desc = noti_desc.replacingOccurrences(of: "|@|", with: "\r\n")
                            let alertController = UIAlertController(title: noti_title, message: desc, preferredStyle: .alert)
                            
                            DispatchQueue.main.async {
                                self.present(alertController, animated: true, completion: nil)
                            }
                            
                            if(app_btn == "confirm") {
                                alertController.addAction(UIAlertAction(title: "계속", style: .default, handler: { (action) in
                                    self.mainImageView.removeFromSuperview()
                                    self.mainImageView = nil
                                }))
                            } else {
                                alertController.addAction(UIAlertAction(title: "종료", style: .default, handler: { (action) in
                                    UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        exit(0)
                                    }
                                }))
                            }
                        } else {
                            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(UInt64(delay_time)!) / 1000)) {
                                self.mainImageView.removeFromSuperview()
                                self.mainImageView = nil
                            }
                        }
                    } else {
                        let updateDesc = update_desc.replacingOccurrences(of: "|@|", with: "\r\n")
                        let alertController = UIAlertController(title: update_title, message: updateDesc, preferredStyle: .alert)
                        
                        DispatchQueue.main.async {
                            self.present(alertController, animated: true, completion: nil)
                        }
                        
                        if(app_update == "1") {
                            alertController.addAction(UIAlertAction(title: "업데이트", style: .default, handler: { (action) in
                                //마켓이동
                                self.goDeviceApp(_url: "https://itunes.apple.com/app/" + app_id)
                                //앱종료
                                UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    exit(0)
                                }
                            }))
                        } else {
                            if(noti_use == "1") {
                                alertController.addAction(UIAlertAction(title: "업데이트", style: .default, handler: { (action) in
                                    //마켓이동
                                    self.goDeviceApp(_url: "https://itunes.apple.com/app/" + app_id)
                                    //앱종료
                                    UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        exit(0)
                                    }
                                }))
                                alertController.addAction(UIAlertAction(title: "계속사용", style: .default, handler: { (action) in
                                    let desc = noti_desc.replacingOccurrences(of: "|@|", with: "\r\n")
                                    let alertController = UIAlertController(title: noti_title, message: desc, preferredStyle: .alert)
                                    
                                    DispatchQueue.main.async {
                                        self.present(alertController, animated: true, completion: nil)
                                    }
                                    
                                    if(app_btn == "confirm") {
                                        alertController.addAction(UIAlertAction(title: "계속", style: .default, handler: { (action) in
                                            self.mainImageView.removeFromSuperview()
                                            self.mainImageView = nil
                                        }))
                                    } else {
                                        alertController.addAction(UIAlertAction(title: "종료", style: .default, handler: { (action) in
                                            UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                exit(0)
                                            }
                                        }))
                                    }
                                }))
                            } else {
                                alertController.addAction(UIAlertAction(title: "업데이트", style: .default, handler: { (action) in
                                    //마켓이동
                                    self.goDeviceApp(_url: "https://itunes.apple.com/app/" + app_id)
                                    //앱종료
                                    UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        exit(0)
                                    }
                                }))
                                alertController.addAction(UIAlertAction(title: "계속사용", style: .default, handler: { (action) in
                                    self.mainImageView.removeFromSuperview()
                                    self.mainImageView = nil
                                }))
                            }
                        }
                    }
                } else {
                    if(noti_use == "1") {
                        let desc = noti_desc.replacingOccurrences(of: "|@|", with: "\r\n")
                        let alertController = UIAlertController(title: noti_title, message: desc, preferredStyle: .alert)
                        
                        DispatchQueue.main.async {
                            self.present(alertController, animated: true, completion: nil)
                        }
                        
                        if(app_btn == "confirm") {
                            alertController.addAction(UIAlertAction(title: "계속", style: .default, handler: { (action) in
                                self.mainImageView.removeFromSuperview()
                                self.mainImageView = nil
                            }))
                        } else {
                            alertController.addAction(UIAlertAction(title: "종료", style: .default, handler: { (action) in
                                UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    exit(0)
                                }
                            }))
                        }
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + (Double(UInt64(delay_time)!) / 1000)) {
                            self.mainImageView.removeFromSuperview()
                            self.mainImageView = nil
                        }
                    }
                }
            }
            
        }
    }
    
    // MARK: [웹뷰 초기 설정 값 정의 실시 및 웹뷰 로드 수행]
//    func mainWebViewInit(_loadUrl:String, _type:String){
//        print("")
//        print("===============================")
//        print("[ViewController >> mainWebViewInit() : 메인 웹뷰 초기 설정 값 정의 실시 및 웹뷰 로드 수행]")
//        print("url : \(_loadUrl)")
//        print("===============================")
//        print("")
//
//        mainWebView.removeFromSuperview()
//        self.activityIndicator.startAnimating()
//
//        // [자바스크립트 통신 경로 지정 실시 : 모두 정의, 로딩화면에서 모두 실행]
//        if(_type == "Splash") {
//            self.addJavaScriptBridgeOpen()
//            self.addJavaScriptBridgeClose()
//            self.addJavaScriptBridgeTest()
//            self.addJavaScriptMetaTag()
//        }
//
//        // [웹뷰 전체 화면 사이즈 설정 실시 : 상태 창 제외]
//        mainWebView.frame = CGRect.init(
//            x: 0,
//            y: statusBarHeight, // 상태 창 길이 제외 위함
//            width: self.view.frame.width, // 웹뷰에 맞게 화면 맞춤
//            height: self.view.frame.height - statusBarHeight // 웹뷰에 맞게 화면 맞춤 길이 맞춤
//        )
//
//        // [웹뷰 캐시 삭제 실시]
//        WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache], modifiedSince: Date(timeIntervalSince1970: 0), completionHandler:{ })
//
//        mainWebView.evaluateJavaScript("navigator.userAgent", completionHandler: { (result, error) in
//            debugPrint(result as Any)
//            debugPrint(error as Any)
//            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
//
//            if let unwrappedUserAgent = result as? String {
//             print("userAgent: \(unwrappedUserAgent)")
//             self.mainWebView.customUserAgent = unwrappedUserAgent + " WpApp WpApp_ios WpVer_" + appVersion!
//            } else {
//             print("failed to get the user agent")
//            }
//         })
//
//        // [mainWebView 웹뷰 옵션값 지정]
//        mainWebView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true  // 자바스크립트 활성화
//        mainWebView.navigationDelegate = self // 웹뷰 변경 상태 감지 위함
//        mainWebView.allowsBackForwardNavigationGestures = true // 웹뷰 뒤로가기, 앞으로 가기 제스처 사용
//        mainWebView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil) // 웹뷰 로드 상태 퍼센트 확인
//        mainWebView.uiDelegate = self // alert 팝업창 이벤트 받기 위함
//        mainWebView.scrollView.bounces = false
//
//        // [웹뷰 화면 비율 설정 및 초기 웹뷰 로드 실시 : get url 주소]
//        view.addSubview(mainWebView)
//
//        //let url = URL (string: _loadUrl) // 웹뷰 로드 주소
//        let url = Bundle.main.url(forResource: "loading", withExtension: "html", subdirectory: "htmls")
//        let fullUrl = URL(string: "?target_url=" + alignUrl + "&device_token=", relativeTo: url)
//        let request = URLRequest(url: fullUrl! as URL)
//        mainWebView.load(request)
//    }
    
    func subWebViewInit(_loadUrl:String, _type:String) {
        print("")
        print("===============================")
        print("[ViewController >> subWebViewInit() : 서브 웹뷰 초기 설정 값 정의 실시 및 웹뷰 로드 수행]")
        print("url : \(_loadUrl)")
        print("===============================")
        print("")
        
        let url = URL (string: _loadUrl)
        
        DispatchQueue.global().async {
            if let content = try? String(contentsOf: url!, encoding: .utf8) {
                DispatchQueue.main.async {
                    if let range = content.range(of: "<title>.*?</title>", options: .regularExpression, range: nil, locale: nil) {
                        self.browser_title = content[range].replacingOccurrences(of: "</?title>", with: "", options: .regularExpression, range: nil)
                        print(self.browser_title)
                    }
                    self.browser_url = url?.host ?? self.alignUrl
                }
            }
        }
        
        subWebView.removeFromSuperview()
        //self.activityIndicator.startAnimating() // 로딩 시작 (사용하지 않을 때 주석)
        
        self.addJavaScriptBridgeOpen()
        self.addJavaScriptBridgeClose()
        self.addJavaScriptBridgeTest()
        self.addJavaScriptMetaTag()
        self.addJavaScriptBridgeLocation()

        // [웹뷰 전체 화면 사이즈 설정 실시 : 상태 창 제외]
        subWebView.frame = CGRect.init(
            x: 0,
            y: statusBarHeight + 5, // 상태 창 길이 제외 위함
            width: self.view.frame.width, // 웹뷰에 맞게 화면 맞춤
            height: self.view.frame.height - statusBarHeight // 웹뷰에 맞게 화면 맞춤 길이 맞춤
        )
        
        // [웹뷰 캐시 삭제 실시]
        WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache], modifiedSince: Date(timeIntervalSince1970: 0), completionHandler:{ })
        
        subWebView.evaluateJavaScript("navigator.userAgent", completionHandler: { (result, error) in
            debugPrint(result as Any)
            debugPrint(error as Any)
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

            if let unwrappedUserAgent = result as? String {
             print("userAgent: \(unwrappedUserAgent)")
             self.subWebView.customUserAgent = unwrappedUserAgent + " WpApp WpApp_ios WpVer_" + appVersion!
            } else {
             print("failed to get the user agent")
            }
         })
        
        // [subWebView 웹뷰 옵션값 지정]
        subWebView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true  // 자바스크립트 활성화
        subWebView.navigationDelegate = self // 웹뷰 변경 상태 감지 위함
        subWebView.allowsBackForwardNavigationGestures = true // 웹뷰 뒤로가기, 앞으로 가기 제스처 사용
        subWebView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil) // 웹뷰 로드 상태 퍼센트 확인
        subWebView.uiDelegate = self // alert 팝업창 이벤트 받기 위함
        
        // [웹뷰 화면 비율 설정 및 초기 웹뷰 로드 실시 : get url 주소]
        view.addSubview(subWebView)
        
        let request = URLRequest(url: url! as URL)
        subWebView.load(request)
        
        // JavaScript 피드백 코드 주입
        injectLocationFeedbackJS()
        
//        //웹뷰 쿠키 가져오기
//        func getCookie() {
//            subWebView.evaluateJavaScript("document.cookie") { (result, error) in
//                if let unwrappedCookie = result as? String {
//                    print("cookie: \(unwrappedCookie)")
//                } else {
//                    print("failed to get the cookie")
//                }
//            }
//        }
    }

    // MARK: [자바스크립트 통신을 위한 초기화 부분]
    let javascriptController = WKUserContentController()
    let javascriptConfig = WKWebViewConfiguration()
    
    func addJavaScriptBridgeLocation() {
        self.javascriptController.add(self, name: "location")
        self.javascriptConfig.userContentController = self.javascriptController
    }
        
    func addJavaScriptBridgeOpen(){
        print("")
        print("===============================")
        print("[ViewController >> addJavaScriptBridgeOpen() : 자바스크립트 통신 브릿지 추가]")
        print("Bridge : open")
        print("===============================")
        print("")
        
        // [open 브릿지 경로 추가]
        self.javascriptController.add(self, name: "open")
        self.javascriptConfig.userContentController = self.javascriptController
        //self.mainWebView = WKWebView(frame: self.view.bounds, configuration: javascriptConfig)
    }
    
    func addJavaScriptBridgeClose(){
        print("")
        print("===============================")
        print("[ViewController >> addJavaScriptBridgeClose() : 자바스크립트 통신 브릿지 추가]")
        print("Bridge : close")
        print("===============================")
        print("")
        // [close 브릿지 경로 추가]
        self.javascriptController.add(self, name: "close")
        self.javascriptConfig.userContentController = self.javascriptController
        //self.mainWebView = WKWebView(frame: self.view.bounds, configuration: javascriptConfig)
    }
    
    func addJavaScriptBridgeTest(){
        print("")
        print("===============================")
        print("[ViewController >> addJavaScriptBridgeTest() : 자바스크립트 통신 브릿지 추가]")
        print("Bridge : test")
        print("===============================")
        print("")
        // [test 브릿지 경로 추가]
        self.javascriptController.add(self, name: "test")
        self.javascriptConfig.userContentController = self.javascriptController
        //self.mainWebView = WKWebView(frame: self.view.bounds, configuration: javascriptConfig)
    }
    
    func addJavaScriptMetaTag() {
        print("")
        print("===============================")
        print("[ViewController >> addJavaScriptMetaTag() : 자바스크립트 줌방지 메타태그 추가]")
        print("===============================")
        print("")
        
        let source: String = "var meta = document.createElement('meta');" +
        "meta.name = 'viewport';" +
        "meta.content = 'width=divice-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';" +
        "var head = document.getElementsByTagName('head')[0];" +
        "head.appendChild(meta);"
        
        let script: WKUserScript = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        self.javascriptController.addUserScript(script)
    }
    
    // JavaScript 피드백 코드 주입 함수
    func injectLocationFeedbackJS() {
        let js = """
        // 웹페이지에 추가할 JavaScript 코드
        document.addEventListener('DOMContentLoaded', function() {
            // 위치 상태 표시 UI 요소 생성
            const locationStatusContainer = document.createElement('div');
            locationStatusContainer.id = 'location-status-container';
            locationStatusContainer.style.cssText = `
                position: fixed;
                bottom: 20px;
                left: 50%;
                transform: translateX(-50%);
                background-color: rgba(0, 0, 0, 0.7);
                color: white;
                padding: 10px 20px;
                border-radius: 5px;
                font-size: 14px;
                z-index: 9999;
                display: none;
                max-width: 90%;
                text-align: center;
            `;
            document.body.appendChild(locationStatusContainer);

            // 로딩 인디케이터 생성
            const spinner = document.createElement('div');
            spinner.className = 'location-spinner';
            spinner.style.cssText = `
                display: inline-block;
                width: 16px;
                height: 16px;
                border: 2px solid rgba(255, 255, 255, 0.3);
                border-radius: 50%;
                border-top-color: white;
                animation: location-spin 1s linear infinite;
                margin-right: 8px;
                vertical-align: middle;
            `;
            
            // 스피너 애니메이션 추가
            const style = document.createElement('style');
            style.textContent = `
                @keyframes location-spin {
                    to { transform: rotate(360deg); }
                }
            `;
            document.head.appendChild(style);

            // 상태 메시지 요소 생성
            const statusText = document.createElement('span');
            statusText.id = 'location-status-text';
            
            // 컨테이너에 요소 추가
            locationStatusContainer.appendChild(spinner);
            locationStatusContainer.appendChild(statusText);

            // 위치 요청 시작 이벤트 리스너
            window.addEventListener('nativeLocationRequest', function() {
                showLocationStatus('위치 정보를 가져오는 중...');
            });

            // 위치 수신 이벤트 리스너
            window.addEventListener('nativeLocation', function(e) {
                const { lat, lng } = e.detail;
                showLocationStatus(`위치 정보 수신 완료: ${lat.toFixed(4)}, ${lng.toFixed(4)}`, 'success');
                
                // 여기서 수신된 위치 정보로 원하는 작업 수행
                // 예: 폼 필드 업데이트, API 호출 등
                
                // 2초 후 상태 표시 숨기기
                setTimeout(hideLocationStatus, 2000);
            });

            // 위치 오류 이벤트 리스너
            window.addEventListener('nativeLocationFail', function(e) {
                showLocationStatus(`위치 정보 오류: ${e.detail.message}`, 'error');
                // 5초 후 상태 표시 숨기기
                setTimeout(hideLocationStatus, 5000);
            });
        });

        // 위치 정보 요청 함수
        function requestLocation() {
            // 상태 표시
            showLocationStatus('위치 정보 요청 중...');
            
            // 네이티브 앱에 위치 요청
            try {
                window.webkit.messageHandlers.location.postMessage('');
            } catch (error) {
                showLocationStatus('위치 요청 오류: 네이티브 기능을 사용할 수 없습니다', 'error');
            }
        }

        // 상태 메시지 표시 함수
        function showLocationStatus(message, type = 'info') {
            const container = document.getElementById('location-status-container');
            const statusText = document.getElementById('location-status-text');
            
            if (!container || !statusText) return;
            
            statusText.textContent = message;
            container.style.display = 'block';
            
            // 메시지 유형에 따른 색상 변경
            if (type === 'error') {
                container.style.backgroundColor = 'rgba(220, 53, 69, 0.9)';
            } else if (type === 'success') {
                container.style.backgroundColor = 'rgba(40, 167, 69, 0.9)';
            } else {
                container.style.backgroundColor = 'rgba(0, 0, 0, 0.7)';
            }
        }

        // 상태 메시지 숨기기 함수
        function hideLocationStatus() {
            const container = document.getElementById('location-status-container');
            if (container) {
                container.style.display = 'none';
            }
        }
        """
        
        let script = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        subWebView.configuration.userContentController.addUserScript(script)
    }
    

    // MARK: [자바스크립트 >> IOS 통신 부분]
    @available(iOS 8.0, *)
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // MARK: [웹 코드] window.webkit.messageHandlers.open.postMessage("[open] 자바스크립트 >> IOS 호출");
        if message.name == "open" { // 브릿지 경로 지정
            let receiveData = message.body // 전달 받은 메시지 확인
            print("")
            print("===============================")
            print("[ViewController >> userContentController() : 자바스크립트 >> IOS]")
            print("Bridge : open")
            print("receiveData : ", receiveData)
            print("===============================")
            print("")
            
            // MARK: [웹 코드] function receive_Open() {} : IOS >> 자바스크립트 데이터 전송 실시
            self.sendFunctionOpen(_send: "") // 널 데이터
        }
        // MARK: [웹 코드] window.webkit.messageHandlers.close.postMessage("[close] 자바스크립트 >> IOS 호출");
        if message.name == "close" { // 브릿지 경로 지정
            let receiveData = message.body // 전달 받은 메시지 확인
            print("")
            print("===============================")
            print("[ViewController >> userContentController() : 자바스크립트 >> IOS]")
            print("Bridge : close")
            print("receiveData : ", receiveData)
            print("===============================")
            print("")
            
            // MARK: [웹 코드] function receive_Close(value) {} : IOS >> 자바스크립트 데이터 전송 실시
            self.sendFunctionClose(_send: "IOS >> 자바스크립트") // 데이터
        }
        // MARK: [웹 코드] window.webkit.messageHandlers.test.postMessage("[test] 자바스크립트 >> IOS 호출");
        if message.name == "test" { // 브릿지 경로 지정
            let receiveData = message.body // 전달 받은 메시지 확인
            print("")
            print("===============================")
            print("[ViewController >> userContentController() : 자바스크립트 >> IOS]")
            print("Bridge : test")
            print("receiveData : ", receiveData)
            print("===============================")
            print("")
            
            // MARK: [웹 코드] function receive_Close(value) {} : IOS >> 자바스크립트 데이터 전송 실시
            self.sendFunctionTest(_send: "") // 널 데이터
        }
        
        if message.name == "location" {
            print("JS에서 위치 요청 받음")
            requestLocation()  // 새로운 함수 호출
//            if CLLocationManager.authorizationStatus() == .authorizedWhenInUse || CLLocationManager.authorizationStatus() == .authorizedAlways {
//                locationManager.requestLocation()
//            } else {
//                locationManager.requestWhenInUseAuthorization()
//            }
        }
    }
    
    
    // MARK: [IOS >> 자바스크립트 통신 부분]
    func sendFunctionOpen(_send:String){
        print("")
        print("===============================")
        print("[ViewController >> sendFunctionOpen() : IOS >> 자바스크립트]")
        print("_send : ", _send)
        print("===============================")
        print("")
        subWebView.evaluateJavaScript("receive_Open('\(_send)')", completionHandler: nil)
        /*self.mainWebView!.evaluateJavaScript("receive_Open('')", completionHandler: {
            (any, err) -> Void in
            print(err ?? "[receive_Open] IOS >> 자바스크립트 : SUCCESS")
        })*/
    }
    func sendFunctionClose(_send:String){
        print("")
        print("===============================")
        print("[ViewController >> sendFunctionClose() : IOS >> 자바스크립트]")
        print("_send : ", _send)
        print("===============================")
        print("")
        subWebView.evaluateJavaScript("receive_Close('\(_send)')", completionHandler: nil)
        /*self.mainWebView!.evaluateJavaScript("receive_Close('')", completionHandler: {
            (any, err) -> Void in
            print(err ?? "[receive_Close] IOS >> 자바스크립트 : SUCCESS")
        })*/
    }
    func sendFunctionTest(_send:String){
        print("")
        print("===============================")
        print("[ViewController >> sendFunctionClose() : IOS >> 자바스크립트]")
        print("_send : ", _send)
        print("===============================")
        print("")
        subWebView.evaluateJavaScript("receive_Test('\(_send)')", completionHandler: nil)
        /*self.mainWebView!.evaluateJavaScript("receive_Test('')", completionHandler: {
            (any, err) -> Void in
            print(err ?? "[receive_Test] IOS >> 자바스크립트 : SUCCESS")
        })*/
    }
    
    func addRefreshControl() {
        refreshControl.backgroundColor = UIColor.clear
        refreshControl.tintColor = UIColor.clear
        //refreshControl.attributedTitle = NSAttributedString(string: "당기면 새로고침합니다.", attributes: [NSAttributedString.Key.foregroundColor: UIColor.white, NSAttributedString.Key.font : UIFont.boldSystemFont(ofSize: 16)])
        refreshControl.addTarget(self, action: #selector(reloadWebView(_:)), for: .valueChanged)
        subWebView.scrollView.addSubview(refreshControl)
        
        //mainWebView.scrollView.bounces = true
        subWebView.scrollView.delegate = self
    }
    
    // [웹뷰 로드 수행 시작 부분]
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        let _startUrl = String(describing: webView.url?.description ?? "")
    
        print("")
        print("===============================")
        print("[ViewController >> didStartProvisionalNavigation() : 웹뷰 로드 수행 시작]")
        print("url : \(_startUrl)")
        print("===============================")
        print("")
        
        //setupActivityIndicator() // 로딩 설정 (사용하지 않을 때 주석)
        //self.activityIndicator.startAnimating() // 로딩 시작 (사용하지 않을 때 주석)
        
//        if(URL(string: alignUrl)?.host != URL(string: _startUrl)?.host) {
//            if(_startUrl.hasPrefix("tel:") || _startUrl.hasPrefix("sms:") || _startUrl.hasPrefix("mailto:")) {
//                self.activityIndicator.stopAnimating()
//                
//                goDeviceApp(_url: _startUrl)
//            } else if(_startUrl.hasPrefix("kakaolink://")) {
//                self.activityIndicator.stopAnimating()
//                subWebView.stopLoading()
//                //UIApplication.shared.open(URL(string: _startUrl)!, options: [:])
//                UIApplication.shared.open(URL(string: _startUrl)!, completionHandler: { (success) in
//                    if(success) {
//                        print("")
//                        print("====================================")
//                        print("[S_Extension >> goAppRun :: 외부 앱 열기 수행 [외부 열기]]")
//                        print("_storeUrl :: ", _startUrl)
//                        print("====================================")
//                        print("")
//                    } else {
//                        let _storeUrl =  "itms-apps://itunes.apple.com/app/id362057947"
//                        
//                        // 마켓 이동 로직 처리 실시
//                        print("")
//                        print("====================================")
//                        print("[S_Extension >> goAppRun :: 앱 스토어 이동 실시 [외부 열기 수행]]")
//                        print("_storeUrl :: ", _storeUrl)
//                        print("====================================")
//                        print("")
//                        if #available(iOS 10.0, *) {
//                            UIApplication.shared.open(URL(string: _storeUrl)!, options: [:], completionHandler: nil)
//                        } else {
//                            UIApplication.shared.openURL(URL(string: _storeUrl)!)
//                        }
//                    }
//                })
//            } else {
//                self.activityIndicator.stopAnimating()
//                subWebView.stopLoading()
//                //UIApplication.shared.open(URL(string: _startUrl)!, options:[:])
//                // [http 주소를 포함한지 확인]
//                if _startUrl.hasPrefix("http") == true || _startUrl.hasPrefix("https") == true {
//                    print("")
//                    print("===============================")
//                    print("[intentWebSiteLink : 웹사이트 이동 실시]")
//                    print("url : ", _startUrl)
//                    print("===============================")
//                    print("")
//                    // [방법 [1]]
//                    //UIApplication.shared.open(URL(string: _url)!, options: [:])
//                    
//                    // [방법 [2]]
//                    guard let url = URL(string: _startUrl) else { return }
//                    let safariViewController = SFSafariViewController(url: url)
//                    DispatchQueue.main.async { [weak self] in
//                        self?.present(safariViewController, animated: false, completion: nil)
//                    }
//                }
//                else {
//                    print("")
//                    print("===============================")
//                    print("[intentWebSiteLink : 접속 주소를 다시 확인해주세요]")
//                    print("url : ", _startUrl)
//                    print("===============================")
//                    print("")
//                }
//            }
//        }
        
        if(URL(string: alignUrl)?.host != URL(string: _startUrl)?.host) {
            if (_startUrl.contains("nid.naver.com/oauth2.0") || _startUrl.contains("nid.naver.com/login/noauth") || _startUrl.contains("nid.naver.com/nidlogin") || _startUrl.contains("kauth.kakao.com/oauth") || _startUrl.contains("accounts.kakao.com/login") || _startUrl.contains("logins.daum.net/accounts") || _startUrl.contains("service.iamport.kr") || _startUrl.contains("mobile.inicis.com")) {
                
            } else {
                if(_startUrl.hasPrefix("tel:") || _startUrl.hasPrefix("sms:") || _startUrl.hasPrefix("mailto:")) {
                    //self.activityIndicator.stopAnimating() // 로딩 종료 (사용하지 않을 때 주석)
                    goDeviceApp(_url: _startUrl)
                } else if(_startUrl.hasPrefix("kakaolink://") || _startUrl.hasPrefix("kakaoopen://")) {
                    //self.activityIndicator.stopAnimating() // 로딩 종료 (사용하지 않을 때 주석)
                    subWebView.stopLoading()
                    //UIApplication.shared.open(URL(string: _startUrl)!, options: [:])
                    UIApplication.shared.open(URL(string: _startUrl)!, completionHandler: { (success) in
                        if(success) {
                            print("")
                            print("====================================")
                            print("[S_Extension >> goAppRun :: 외부 앱 열기 수행 [외부 열기]]")
                            print("_storeUrl :: ", _startUrl)
                            print("====================================")
                            print("")
                        } else {
                            let _storeUrl =  "itms-apps://itunes.apple.com/app/id362057947"
                            
                            // 마켓 이동 로직 처리 실시
                            print("")
                            print("====================================")
                            print("[S_Extension >> goAppRun :: 앱 스토어 이동 실시 [외부 열기 수행]]")
                            print("_storeUrl :: ", _storeUrl)
                            print("====================================")
                            print("")
                            if #available(iOS 10.0, *) {
                                UIApplication.shared.open(URL(string: _storeUrl)!, options: [:], completionHandler: nil)
                            } else {
                                UIApplication.shared.openURL(URL(string: _storeUrl)!)
                            }
                        }
                    })
                } else {
                    //self.activityIndicator.stopAnimating() // 로딩 종료 (사용하지 않을 때 주석)
                    subWebView.stopLoading()
                    //UIApplication.shared.open(URL(string: _startUrl)!, options:[:])
                    // [http 주소를 포함한지 확인]
                    if _startUrl.hasPrefix("http") == true || _startUrl.hasPrefix("https") == true {
                        print("")
                        print("===============================")
                        print("[intentWebSiteLink : 웹사이트 이동 실시]")
                        print("url : ", _startUrl)
                        print("===============================")
                        print("")
                        // [방법 [1]]
                        //UIApplication.shared.open(URL(string: _url)!, options: [:])
                        
                        // [방법 [2]]
                        guard let url = URL(string: _startUrl) else { return }
                        let safariViewController = SFSafariViewController(url: url)
                        DispatchQueue.main.async { [weak self] in
                            self?.present(safariViewController, animated: false, completion: nil)
                        }
                    }
                    else {
                        print("")
                        print("===============================")
                        print("[intentWebSiteLink : 접속 주소를 다시 확인해주세요]")
                        print("url : ", _startUrl)
                        print("===============================")
                        print("")
                    }
                }
            }
            
        }
    }
    
    
    // [웹뷰 로드 상태 퍼센트 확인 부분]
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        // 0 ~ 1 사이의 실수형으로 결과값이 출력된다 [0 : 로딩 시작, 1 : 로딩 완료]
        print("")
        print("===============================")
        print("[ViewController >> observeValue() : 웹뷰 로드 상태 확인]")
        print("loading : \(Float(subWebView.estimatedProgress)*100)")
        print("===============================")
        print("")
    }
    
    var hasSentLocation = false
    
    // [웹뷰 로드 수행 완료 부분]
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let _endUrl = String(describing: webView.url?.description ?? "")
        print("")
        print("===============================")
        print("[ViewController >> didFinish() : 웹뷰 로드 수행 완료]")
        print("url : \(_endUrl)")
        print("===============================")
        print("")
        
        subWebView.evaluateJavaScript("document.getElementsByTagName('html')[0].innerHTML") { innerHTML, error in
            let _html = String(describing: innerHTML ?? "")
            if(_html.contains("overscroll-behavior-y: none;")) {
                self.subWebView.scrollView.bounces = false
            } else {
                self.subWebView.scrollView.bounces = true
            }
        }
        
        subWebView.evaluateJavaScript("document.cookie") { (result, error) in
            if let unwrappedCookie = result as? String {
                print("cookie: \(unwrappedCookie)")
            } else {
                print("failed to get the cookie")
            }
        }
        //self.activityIndicator.stopAnimating() // 로딩 종료 (사용하지 않을 때 주석)
        
        // 위치 전달은 한 번만
        if !hasSentLocation {
            hasSentLocation = true
            if CLLocationManager.authorizationStatus() == .authorizedWhenInUse ||
                CLLocationManager.authorizationStatus() == .authorizedAlways {
                locationManager.requestLocation()
            }
        }
        
    }
    
    // [웹뷰 로드 수행 에러 확인]
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let _nsError = error as NSError
        let _errorUrl = String(describing: webView.url?.description ?? "")
        print("")
        print("===============================")
        print("[ViewController >> didFail() : 웹뷰 로드 수행 에러]")
        print("_errorUrl : \(_errorUrl)")
        print("_errorCode : \(_nsError)")
        //print("_errorMsg : \(S_WebViewErrorCode().checkError(_errorCode: 1019))")
        print("===============================")
        print("")
    }

    
    // [웹뷰 실시간 url 변경 감지 실시]
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let _shouldUrl = String(describing: webView.url?.description ?? "")
        var action: WKNavigationActionPolicy?
        defer {
            decisionHandler(action ?? .allow)
        }
        guard let url = navigationAction.request.url else { return }
        print("")
        print("===============================")
        print("[ViewController >> decidePolicyFor() : 웹뷰 실시간 url 변경 감지]")
        print("_shouldUrl : \(_shouldUrl)")
        print("requestUrl : \(url)")
        print("===============================")
        print("")
        
        subWebView.evaluateJavaScript("document.cookie") { (result, error) in
            if let unwrappedCookie = result as? String {
                print("cookie: \(unwrappedCookie)")
            } else {
                print("failed to get the cookie")
            }
        }
    }
    
    
    // [웹뷰 모달창 닫힐때 앱 종료현상 방지]
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
        
    // [alert 팝업창 처리]
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void){
        print("")
        print("===============================")
        print("[ViewController >> runJavaScriptAlertPanelWithMessage() : alert 팝업창 처리]")
        print("message : ", message)
        print("===============================")
        print("")
        
        let alertController = UIAlertController(title: "알림", message: message, preferredStyle: .alert)
        
        if(message == "NULL_DEVICE_TOKEN") {
            alertController.addAction(UIAlertAction(title: "종료", style: .default, handler: { (action) in completionHandler()
                exit(0)
            }))
        } else {
            alertController.addAction(UIAlertAction(title: "확인", style: .default, handler: { (action) in completionHandler() }))
        }
        self.present(alertController, animated: true, completion: nil)
    }


    // [confirm 팝업창 처리]
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        print("")
        print("===============================")
        print("[ViewController >> runJavaScriptConfirmPanelWithMessage() : confirm 팝업창 처리]")
        print("message : ", message)
        print("===============================")
        print("")
        let alertController = UIAlertController(title: "", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "취소", style: .default, handler: { (action) in completionHandler(false) }))
        alertController.addAction(UIAlertAction(title: "확인", style: .default, handler: { (action) in completionHandler(true) }))
        self.present(alertController, animated: true, completion: nil)
    }

    var newWebView: WKWebView!
    
    // [href="_blank" 링크 이동 처리]
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        print("")
        print("===============================")
        print("[ViewController >> createWebViewWith() : href=_blank 링크 이동]")
        print("===============================")
        print("")
        
        let url = navigationAction.request.url
        
        if let content = try? String(contentsOf: url!, encoding: .utf8) {
            if let range = content.range(of: "<title>.*?</title>", options: .regularExpression, range: nil, locale: nil) {
                self.pop_browser_title = content[range].replacingOccurrences(of: "</?title>", with: "", options: .regularExpression, range: nil)
                print(self.pop_browser_title)
            }
            self.pop_browser_url = url?.host ?? self.alignUrl
        } else {
            self.pop_browser_title = self.browser_title
            self.pop_browser_url = self.browser_url
        }

//        if(URL(string: alignUrl)?.host != URL(string: navigationAction.request.description)?.host) {
//            if navigationAction.targetFrame == nil {
//                webView.load(navigationAction.request)
//            }
//            return nil
//        } else {
//            popupWebView?.removeFromSuperview()
//            popupWebView = WKWebView(frame: CGRect.init(
//                x: 0,
//                y: statusBarHeight,
//                width: view.frame.width,
//                height: view.frame.height - statusBarHeight
//            ), configuration: configuration)
//            popupWebView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//            popupWebView?.navigationDelegate = self
//            popupWebView?.uiDelegate = self
//            popupWebView?.allowsBackForwardNavigationGestures = true
//            popupWebView?.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
//            view.addSubview(popupWebView!)
//
//            let popupCloseBtn = UIButton(frame: CGRect.init(x: 0, y: (view.frame.height - statusBarHeight - 50), width: view.frame.width, height: 50))
//            popupCloseBtn.backgroundColor = UIColor(red: 0.20, green: 0.58, blue: 1.00, alpha: 1.00)
//            popupCloseBtn.setTitle("창닫기", for: .normal)
//            popupCloseBtn.addTarget(self, action: #selector(closePopup), for: .touchUpInside)
//            self.popupWebView?.addSubview(popupCloseBtn)
//
//            return popupWebView!
//        }
        
        popupWebView?.removeFromSuperview()
        popupWebView = WKWebView(frame: CGRect.init(
            x: 0,
            y: statusBarHeight,
            width: view.frame.width,
            height: view.frame.height - statusBarHeight
        ), configuration: configuration)
        popupWebView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        popupWebView?.navigationDelegate = self
        popupWebView?.uiDelegate = self
        popupWebView?.allowsBackForwardNavigationGestures = true
        popupWebView?.scrollView.contentInset = UIEdgeInsets(top: 47, left: 0, bottom: 0, right: 0)
        popupWebView?.evaluateJavaScript("navigator.userAgent", completionHandler: { (result, error) in
            if let unwrappedUserAgent = result as? String {
             print("userAgent: \(unwrappedUserAgent)")
             self.popupWebView?.customUserAgent = unwrappedUserAgent + " WpApp WpPop"
            } else {
             print("failed to get the user agent")
            }
         })
        view.addSubview(popupWebView!)
        
        let popupHeader = UIView(frame: CGRect.init(x: 0, y: 0, width: view.frame.width, height: 52))
        popupHeader.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
        popupHeader.layer.addBorder([.bottom], color: UIColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 0.5), width: 1.0)
        
        let popupCloseBtn = UIButton(frame: CGRect.init(x:0, y:0, width: 50, height: 48))
//        popupCloseBtn.setTitle("X", for: .normal)
        popupCloseBtn.setImage(UIImage(named: "close_btn"), for: .normal)
        popupCloseBtn.imageEdgeInsets = UIEdgeInsets(top: 34, left: 34, bottom: 34, right: 34)
        popupCloseBtn.setTitleColor(UIColor(red: 0.26, green: 0.26, blue: 0.26, alpha: 1.00), for: .normal)
        popupCloseBtn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        popupCloseBtn.addTarget(self, action: #selector(closePopup), for: .touchUpInside)
        
        popupHeader.addSubview(popupCloseBtn)
        
        let popupHeaderTitle = UITextView(frame: CGRect.init(x: 45, y: 0, width: view.frame.width - 45, height: 30))
//        let popupHeaderTitle = UITextView(frame: CGRect.init(x: 45, y: 0, width: view.frame.width, height: 30))
        popupHeaderTitle.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
        popupHeaderTitle.text = self.pop_browser_title
        popupHeaderTitle.isEditable = false
        popupHeaderTitle.font = UIFont.boldSystemFont(ofSize: 16.0)
        popupHeaderTitle.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1.00)
        popupHeaderTitle.textContainer.maximumNumberOfLines = 1
        popupHeaderTitle.textContainer.lineBreakMode = .byTruncatingTail
        
        let popupSubTitle = UITextView(frame: CGRect.init(x: 45, y: 22, width: view.frame.width, height: 25))
        popupSubTitle.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
        popupSubTitle.text = self.pop_browser_url
        popupSubTitle.isEditable = false
        popupSubTitle.font = UIFont.systemFont(ofSize: 12.0)
        popupSubTitle.textColor = UIColor(red: 0.40, green: 0.40, blue: 0.40, alpha: 1.00)
        
        popupHeader.addSubview(popupSubTitle)
        popupHeader.addSubview(popupHeaderTitle)
        
        self.popupWebView?.addSubview(popupHeader)

        return popupWebView!
    }

//    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
//        let frame = UIScreen.main.bounds
//        newWebView = WKWebView(frame: frame, configuration: configuration)
//
//        newWebView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//
//        newWebView?.navigationDelegate = self
//        newWebView?.uiDelegate = self
//        view.addSubview(newWebView!)
//
//        return newWebView!
//    }
    
    @objc func closePopup(sender: Any) {
        popupWebView?.removeFromSuperview()
        popupWebView = nil
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        webView.removeFromSuperview()
        popupWebView = nil
    }
    
//    func scrollViewDidScroll(_ scrollView: UIScrollView) {
//        let offsetY = CGFloat(mainWebView.scrollView.contentOffset.y)
//
//        if(offsetY.sign == .minus) {
//            mainWebView.frame = CGRect.init(x: 0, y: -(offsetY) + self.view.safeAreaInsets.top, width: self.view.frame.size.width, height: self.view.frame.size.height - self.view.safeAreaInsets.top - self.view.safeAreaInsets.bottom)
//        } else {
//            mainWebView.frame = CGRect.init(x: 0, y: 0 + self.view.safeAreaInsets.top, width: self.view.frame.size.width, height: self.view.frame.size.height - self.view.safeAreaInsets.top - self.view.safeAreaInsets.bottom)
//        }
//    }
    
    // 위치 상태 레이어를 생성하는 함수
    func createLocationStatusView() {
        // 이미 존재한다면 제거
        removeLocationStatusView()
        
        // 상태 뷰 생성
        locationStatusView = UIView(frame: CGRect(x: 0, y: statusBarHeight + 5, width: self.view.frame.width, height: 40))
        locationStatusView?.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.7)
        locationStatusView?.layer.cornerRadius = 5
        locationStatusView?.clipsToBounds = true
        locationStatusView?.alpha = 0 // 초기에는 투명하게 설정
        
        // 로딩 인디케이터 생성
        locationIndicator = UIActivityIndicatorView(style: .white)
        locationIndicator?.center = CGPoint(x: 25, y: 20)
        locationIndicator?.startAnimating()
        locationStatusView?.addSubview(locationIndicator!)
        
        // 상태 텍스트 라벨 생성
        locationStatusLabel = UILabel(frame: CGRect(x: 50, y: 0, width: self.view.frame.width - 60, height: 40))
        locationStatusLabel?.text = "위치 정보를 불러오는 중..."
        locationStatusLabel?.textColor = .white
        locationStatusLabel?.font = UIFont.systemFont(ofSize: 14)
        locationStatusView?.addSubview(locationStatusLabel!)
        
        // 웹뷰 위에 추가
        self.view.addSubview(locationStatusView!)
        
        // 애니메이션과 함께 나타나게 함
        UIView.animate(withDuration: 0.3) {
            self.locationStatusView?.alpha = 1
        }
    }

    // 위치 상태 레이어를 제거하는 함수
    func removeLocationStatusView() {
        if locationStatusView != nil {
            UIView.animate(withDuration: 0.3, animations: {
                self.locationStatusView?.alpha = 0
            }) { _ in
                self.locationStatusView?.removeFromSuperview()
                self.locationStatusView = nil
                self.locationStatusLabel = nil
                self.locationIndicator = nil
            }
        }
    }

    // 위치 상태 업데이트 함수
    func updateLocationStatus(message: String, isError: Bool = false) {
        if locationStatusView == nil {
            createLocationStatusView()
        }
        
        locationStatusLabel?.text = message
        
        if isError {
            locationStatusView?.backgroundColor = UIColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 0.7)
            
            // 에러 상태는 3초 후 자동으로 사라지게 함
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.removeLocationStatusView()
            }
        } else {
            locationStatusView?.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.7)
        }
    }

    // 위치 요청 함수 - userContentController에서 호출됨
    func requestLocation() {
        updateLocationStatus(message: "위치 정보 요청 중...")
        
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse ||
           CLLocationManager.authorizationStatus() == .authorizedAlways {
            locationManager.requestLocation()
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }
            
    // [외부 앱 실행 실시]
    /*
    1. tel , mailto , sms , l 등을 사용해 디바이스 외부 앱을 수행할 수 있습니다
    2. 전화 걸기 : tel:010-1234-5678
    3. 메일 보내기 : mailto:honggildung@test.com
    4. 문자 보내기 : sms:010-5678-1234
    5. 링크 이동 : https://naver.com
    6. 호출 예시 : goDeviceApp(_url: "tel:010-1234-5678")
    */
    func goDeviceApp(_url : String) {

        //스키마명을 사용해 외부앱 실행 실시 [사용가능한 url 확인]
        if let openApp = URL(string: _url), UIApplication.shared.canOpenURL(openApp) {
            print("")
            print("====================================")
            print("[goDeviceApp : 디바이스 외부 앱 열기 수행]")
            print("링크 주소 : \(_url)")
            print("====================================")
            print("")
            // 버전별 처리 실시
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(openApp, options: [:], completionHandler: nil)
            }
            else {
                UIApplication.shared.openURL(openApp)
            }
        }
        //스키마명을 사용해 외부앱 실행이 불가능한 경우
        else {
            print("")
            print("====================================")
            print("[goDeviceApp : 디바이스 외부 앱 열기 실패]")
            print("링크 주소 : \(_url)")
            print("====================================")
            print("")
        }
    }

    func getQueryStringParameter(url: String, param: String) -> String? {
        guard let url = URLComponents(string: url) else { return nil }
        return url.queryItems?.first(where: { $0.name == param })?.value
    }
    
    // MARK: - [비동기 http 통신 요청 수행 실시]
    func callHttpAsync(reqUrl : String, completion: @escaping (Bool, String)->()) {
        
        /*
        // -----------------------------------------
        [callHttpAsync 메소드 설명]
        // -----------------------------------------
        1. 비동기 http 통신 수행 및 리턴 결과 콜백 반환 실시
        // -----------------------------------------
        2. 호출 방법 :
         self.callHttpAsync(reqUrl: "http://jsonplaceholder.typicode.com/posts?userId=1&id=1"){(result, msg) in
             print("")
             print("====================================")
             print("[A_Main >> callHttpAsync() :: 비동기 http 통신 콜백 확인]")
             print("result :: ", result)
             print("msg :: ", msg)
             print("====================================")
             print("")
         }
        // -----------------------------------------
        3. 사전 설정 사항 :
         - 필요 info plist 설정
           [1] http 허용 : App Transport Security Settings >> Allow Arbitrary Loads >> YES
        // -----------------------------------------
        */
        
        
        // [http 비동기 방식을 사용해서 http 요청 수행 실시]
        let urlComponents = URLComponents(string: reqUrl)
        var requestURL = URLRequest(url: (urlComponents?.url)!)
        requestURL.httpMethod = "GET" // GET
        requestURL.addValue("application/x-www-form-urlencoded; charset=utf-8;", forHTTPHeaderField: "Content-Type") // header settings
        print("")
        print("====================================")
        print("[C_Util >> callHttpAsync() :: http 통신 요청 실시]")
        print("-------------------------------")
        print("주 소 :: ", requestURL)
        print("====================================")
        print("")
        
        
        // [http 요쳥을 위한 URLSessionDataTask 생성]
        let dataTask = URLSession.shared.dataTask(with: requestURL, completionHandler: { (data, response, error) in

            // [error가 존재하면 종료]
            guard error == nil else {
                print("")
                print("====================================")
                print("[C_Util >> callHttpAsync() :: http 통신 요청 실패]")
                print("-------------------------------")
                print("주 소 :: ", requestURL)
                print("-------------------------------")
                print("fail :: ", error?.localizedDescription ?? "")
                print("====================================")
                print("")
                
                // [콜백 반환]
                completion(false, error?.localizedDescription ?? "")
                return
            }

            // [status 코드 체크 실시]
            let successsRange = 200..<300
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, successsRange.contains(statusCode)
            else {
                print("")
                print("====================================")
                print("[C_Util >> callHttpAsync() :: http 통신 요청 에러]")
                print("-------------------------------")
                print("주 소 :: ", requestURL)
                print("-------------------------------")
                print("error :: ", (response as? HTTPURLResponse)?.statusCode ?? 0)
                print("-------------------------------")
                print("msg :: ", (response as? HTTPURLResponse)?.description ?? "")
                print("====================================")
                print("")
                
                // [콜백 반환]
                completion(false, (response as? HTTPURLResponse)?.description ?? "")
                return
            }

            // [response 데이터 획득]
            let resultCode = (response as? HTTPURLResponse)?.statusCode ?? 0 // [상태 코드]
            let resultLen = data! // [데이터 길이]
            let resultData = String(data: resultLen, encoding: .utf8) ?? "" // [데이터 확인]
            print("")
            print("====================================")
            print("[C_Util >> callHttpAsync() :: http 통신 성공]")
            print("-------------------------------")
            print("주 소 :: ", requestURL)
            print("-------------------------------")
            print("resultCode :: ", resultCode)
            print("-------------------------------")
            print("resultLen :: ", resultLen)
            print("-------------------------------")
            print("resultData :: ", resultData)
            print("====================================")
            print("")
            
            // [콜백 반환]
            completion(true, resultData)
        })

        // [network 통신 실행]
        dataTask.resume()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            updateLocationStatus(message: "위치 정보를 가져올 수 없습니다.", isError: true)
            return
        }

        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude
        
        updateLocationStatus(message: "위치: \(String(format: "%.4f", lat)), \(String(format: "%.4f", lng)) 전송 중...")

        let startJs = "window.dispatchEvent(new CustomEvent('nativeLocationRequest'));"
        let endJs = """
            window.dispatchEvent(new CustomEvent('nativeLocation', {
                detail: { lat: \(lat), lng: \(lng) }
            }));
        """

        DispatchQueue.main.async {
            // 요청 시작 알림
            self.subWebView.evaluateJavaScript(startJs, completionHandler: nil)

            // 위치 전달 - 지연시간을 줄이고 진행상황 표시
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {  // 0.3 → 0.1로 변경
                self.subWebView.evaluateJavaScript(endJs) { result, error in
                    if let error = error {
                        self.updateLocationStatus(message: "위치 전송 실패: \(error.localizedDescription)", isError: true)
                    } else {
                        self.updateLocationStatus(message: "위치 정보가 성공적으로 전송되었습니다.")
                        // 성공 메시지를 1초간 표시 후 제거
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.removeLocationStatusView()
                        }
                    }
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        updateLocationStatus(message: "위치 가져오기 실패: \(error.localizedDescription)", isError: true)

        let failJs = "window.dispatchEvent(new CustomEvent('nativeLocationFail', { detail: { message: '\(error.localizedDescription)' } }));"
        DispatchQueue.main.async {
            self.subWebView.evaluateJavaScript(failJs, completionHandler: nil)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            updateLocationStatus(message: "위치 정보를 가져오는 중...")
            locationManager.requestLocation()
        case .denied, .restricted:
            updateLocationStatus(message: "위치 권한이 거부되었습니다. 설정에서 변경해주세요.", isError: true)
        case .notDetermined:
            updateLocationStatus(message: "위치 권한을 요청하는 중...")
        @unknown default:
            updateLocationStatus(message: "알 수 없는 위치 권한 상태", isError: true)
        }
    }

}

