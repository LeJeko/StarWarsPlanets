//
//  PlanetsTableViewController.swift
//  StarWars
//
//  Created by Jérôme Haegeli on 06.10.18.
//  Copyright © 2018 Jeko. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class PlanetsTableViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    
    //--------------------
    //MARK: - Properties
    //--------------------
    
    var planets = [Planet]()
    
    var filteredPlanets = [Planet]()
    let searchController = UISearchController(searchResultsController: nil)
    
    private lazy var store: DataStore = {
        
        let provider = DataStore()
        provider.fetchedResultsControllerDelegate = self
        return provider
    }()
    
    //--------------------
    //MARK: - View Methods
    //--------------------
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        tableView.delegate = self

        //Load data from SWAPI
        store.loadDataForPlanets()

        //Search Bar
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        //searchController.hidesNavigationBarDuringPresentation = false
        definesPresentationContext = true
        searchController.searchBar.searchBarStyle = .minimal
        searchController.searchBar.backgroundColor = #colorLiteral(red: 0.1208161485, green: 0.1208161485, blue: 0.1208161485, alpha: 1)
        searchController.searchBar.tintColor = UIColor.green
        let textFieldInsideSearchBar = searchController.searchBar.value(forKey: "searchField") as? UITextField
        textFieldInsideSearchBar?.textColor = UIColor.white
        tableView.tableHeaderView = searchController.searchBar
        tableView.backgroundColor = UIColor.black
        //Hiding empty table view rows
        tableView.tableFooterView = UIView(frame: .zero)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    //--------------------
    // MARK: - Navigation
    //--------------------
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //Edit the back button title displayed in the next vc
        let backItem = UIBarButtonItem()
        backItem.title = ""
        navigationItem.backBarButtonItem = backItem
        
        switch segue.identifier {
        case "showPlanetDetails"?:
            if let selectedIndexPath = tableView.indexPathsForSelectedRows?.first {
                let planet: Planet
                if searchController.isActive && searchController.searchBar.text != "" {
                    planet = filteredPlanets[selectedIndexPath.row]
                } else {
                    planet = store.fetchedResultsController.fetchedObjects![selectedIndexPath.row]
                    // planets[selectedIndexPath.row]
                }
                let destinationVC = segue.destination as! PlanetDetailsTableViewController
                destinationVC.planet = planet
                destinationVC.store = store
            }
            
            
        default:
            preconditionFailure("Unexpected segue identifier.")
        }
    }
    
    
    //--------------------
    //MARK: - Methods
    //--------------------
    
    func filterContentForSearchText(searchText: String, scope: String = "All") {
        filteredPlanets = store.fetchedResultsController.fetchedObjects!.filter { planet in
            if let name = planet.name {
                let result = name.lowercased().contains(searchText.lowercased())
                return result
            } else {
                return false
            }
        }
        tableView.reloadData()
    }
    
    //--------------------
    //MARK: - Actions
    //--------------------
    
    ///flush data and reload from API
    
    @IBAction func reloadData(_ sender: UIBarButtonItem) {
        
        self.store.deleteAllData("Planet")
        self.store.loadDataForPlanets()
        
    }
    
}

//--------------------
// MARK: - SearchController
//--------------------

extension PlanetsTableViewController: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchText: searchController.searchBar.text!)
    }
    
}

//--------------------
// MARK: - UITableViewDataSource and UITableViewDelegate
//--------------------

extension PlanetsTableViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searchController.isActive && searchController.searchBar.text != "" {
            return filteredPlanets.count
        }
        return store.fetchedResultsController.fetchedObjects?.count ?? 0
        
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let reuseIdentifier = "planetCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? UITableViewCell(style: .default, reuseIdentifier: reuseIdentifier)
        let planet: Planet
        if searchController.isActive && searchController.searchBar.text != "" {
            planet = filteredPlanets[indexPath.row]
        } else {
            guard let plnt = store.fetchedResultsController.fetchedObjects?[indexPath.row] else { return cell }
            planet = plnt
        }
        
        cell.textLabel?.text = planet.name
        return cell
        
    }

}

//--------------------
//MARK: - NSFetchedResultsControllerDelegate
//--------------------

extension PlanetsTableViewController {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .delete:
            tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
        case .move:
            break
        case .update:
            break
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .fade)
        case .update:
            tableView.reloadRows(at: [indexPath!], with: .fade)
        case .move:
            tableView.moveRow(at: indexPath!, to: newIndexPath!)
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}
