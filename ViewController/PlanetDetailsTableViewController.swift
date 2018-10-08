//
//  PlanetDetailsTableViewController.swift
//  StarWars
//
//  Created by Jérôme Haegeli on 06.10.18.
//  Copyright © 2018 Jeko. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class PlanetDetailsTableViewController: UITableViewController {
    
    //--------------------
    //MARK: - Properties
    //--------------------
    
    
    var planet: Planet!
    var store: DataStore!
    
    var films: [Film] = []
    var persons: [Person] = []
    
    //--------------------
    //MARK: - View's Methods
    //--------------------
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = planet.name
        films = planet.films?.allObjects as! [Film]
        persons = planet.residents?.allObjects as! [Person]
        
        tableView.backgroundColor = UIColor.black
        tableView.allowsSelection = false
        //Hiding empty table view rows
        tableView.tableFooterView = UIView(frame: .zero)
        
        updateConnections()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.tableView.estimatedRowHeight = 70 // for example. Set your average height
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.reloadData()
    }
    
    //--------------------
    //MARK: - Table View Methods
    //--------------------
    
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 8
        case 1: return films.count
        case 2: return persons.count
        default: return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view:UIView, forSection: Int) {
        if let headerTitle = view as? UITableViewHeaderFooterView {
            headerTitle.textLabel?.textColor = UIColor.green
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Details"
        case 1: return "Films"
        case 2: return "Residents"
        default: return "Section Header"
        }
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        
        switch indexPath.section {
        case 0:
            cell = buildCellForDetails(indexPath)
        case 1:
            cell = tableView.dequeueReusableCell(withIdentifier: "basicCell", for: indexPath)
            cell.textLabel?.text = films[indexPath.row].title
        case 2:
            cell = tableView.dequeueReusableCell(withIdentifier: "basicCell", for: indexPath)
            cell.textLabel?.text = persons[indexPath.row].name
        default:
            cell = tableView.dequeueReusableCell(withIdentifier: "basicCell", for: indexPath)
            cell.textLabel?.text = "Unknown Cell"
        }
        return cell
    }

    //--------------------
    //MARK: - Methods
    //--------------------
    
    func buildCellForDetails(_ indexPath: IndexPath) -> UITableViewCell {
        
        let reuseIdentifier = "columnsDetailCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! ColumnsDetailCell
        let index = indexPath.row
        switch index {
        case 0:
            cell.title.text = "Climate:"
            if let climate = planet.climate {
                cell.detail.text = climate
                
            } else {
                cell.detail.text = "unknown"
            }
        case 1:
            cell.title.text = "Terrain:"
            if let terrain = planet.terrain {
                cell.detail.text = terrain
            } else {
                cell.detail.text = "unknown"
            }
        case 2:
            cell.title.text = "Water:"
            cell.detail.text = "\(planet.surface_water) %"
        case 3:
            cell.title.text = "Gravity:"
            cell.detail.text = "\(planet.gravity) Gs."
            
        case 4:
            cell.title.text = "Diameter:"
            if planet.diameter != 0 {
                cell.detail.text = "\(planet.diameter) km."
            } else {
                cell.detail.text = "unknown"
            }
        case 5:
            cell.title.text = "Population:"
            cell.detail.text = "\(planet.population)"
            
        case 6:
            cell.title.text = "Rotation:"
            if planet.rotation_period != 0 {
                cell.detail.text = "\(planet.rotation_period) hours"
            } else {
                cell.detail.text = "unknown"
            }
        case 7:
            cell.title.text = "Orbit:"
            if planet.orbital_period != 0  {
                cell.detail.text = "\(planet.orbital_period) hours"
            } else {
                cell.detail.text = "unknown"
            }
        default: break;
        }
        return cell
        
    }
    
    ///make all the connections for the selected resource
    func updateConnections() {
        self.createFilmsConnection(fromPlanet: planet, toFilms: planet?.film_urls as? [String])
        self.createPersonsConnection(fromPlanet: planet, toPersons: planet?.resident_urls as? [String])
        tableView.reloadData()
    }
    
    ///make the connections between the planet and the films
    func createFilmsConnection(fromPlanet planet: Planet, toFilms films: [String]?) {
        //check if the films array url is empty
        guard let urls = films else {
            return
        }
        //for each film url
        for url in urls {
            
            //Create the fetch request for the film
            let fetchRequest: NSFetchRequest<Film> = Film.fetchRequest()
            let predicate = NSPredicate(format: "\(#keyPath(Film.url)) == %@", url)
            fetchRequest.predicate = predicate
            
            var fetchedFilms: [Film]?
            let context = store.persistentContainer.viewContext
            
            //make the request
            context.performAndWait {
                fetchedFilms = try? fetchRequest.execute()
            }
            //is there a film with the same url in the core data?
            if let existingFilm = fetchedFilms?.first {
                //Yes, make the connection
                planet.films?.adding(existingFilm)
                self.films.append(existingFilm)
                do {
                    try context.save()
                } catch let error {
                    print("Impossible to make connection: \(error)")
                }
            }
        }
    }
    
    
    ///make the connections between the planet and the characters
    func createPersonsConnection(fromPlanet planet: Planet, toPersons persons: [String]?) {
        //check if the persons array url is empty
        guard let urls = persons else {
            return
        }
        //for each persons url
        for url in urls {
            
            //Create the fetch request for the person
            let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
            let predicate = NSPredicate(format: "\(#keyPath(Person.url)) == %@", url)
            fetchRequest.predicate = predicate
            
            var fetchedPersons: [Person]?
            let context = store.persistentContainer.viewContext
            
            //make the request
            context.performAndWait {
                fetchedPersons = try? fetchRequest.execute()
            }
            //is there a film with the same url in the core data?
            if let existingPerson = fetchedPersons?.first {
                //Yes, make the connection
                planet.residents?.adding(existingPerson)
                self.persons.append(existingPerson)
                do {
                    try context.save()
                } catch let error {
                    print("Impossible to make connection: \(error)")
                }
            }
        }
    }
    
    //--------------------
    //MARK: - Actions
    //--------------------
    
    
    ///Display images for the resource through google images

    @IBAction func searchImages(_ sender: UIBarButtonItem) {
        
        guard  let name = planet.name else {
            return
        }
        //presenting the web view controller
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let webViewController = storyboard.instantiateViewController(withIdentifier: "webViewController") as! WebViewController
        webViewController.stringToSearch = name
        self.present(webViewController, animated: true, completion: nil)
    }
    
}

