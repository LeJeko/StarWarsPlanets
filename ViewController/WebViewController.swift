//
//  WebViewController.swift
//  StarWars
//
//  Created by Jérôme Haegeli on 06.10.18.
//  Copyright © 2018 Jeko. All rights reserved.
//

import UIKit
import WebKit

class WebViewController: UIViewController {
    
    //--------------------
    //MARK: - Outlets
    //--------------------
    
    @IBOutlet weak var webView: WKWebView!

    
    
    //--------------------
    //MARK: - Properties
    //--------------------
    
    ///contains the resource to search into the google images library
    var stringToSearch: String!
    
    ///the base url to search through google images
    let baseURL = "http://www.google.com/images?q=Star+Wars+"
    
    ///the query string to search
    var queryString: String {
        get {
            let query = String(stringToSearch.map {
                $0 == " " ? "+" : $0
            }).folding(options: .diacriticInsensitive, locale: .current)
            return query
        }
    }
    
    //--------------------
    //MARK: - View's Methods
    //--------------------
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let url = URL(string: baseURL + queryString);
        let requestObj = URLRequest(url: url!);
        webView.load(requestObj as URLRequest);
    }
    
    //--------------------
    //MARK: - Actions
    //--------------------
    
    ///Dismiss the view controller
    @IBAction func searchDone(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    
}
