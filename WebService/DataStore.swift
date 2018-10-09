//
//  DataStore.swift
//  StarWars
//
//  Created by Jérôme Haegeli on 06.10.18.
//  Copyright © 2018 Jeko. All rights reserved.
//

import Foundation
import CoreData

//--------------------
//MARK: - Result Types
//--------------------

enum PersonsResult {
    case success([Person])
    case failure(Error)
}

enum FilmsResult {
    case success([Film])
    case failure(Error)
}

enum PlanetsResult {
    case success([Planet])
    case failure(Error)
}


//--------------------
//MARK: - Error Types
//--------------------

class DataStore {

    /**
     Delegate of the fetchedResultsController.
     Give consumers a chance to upate UI when the fetchedResultsController content is changed.
     */
    weak var fetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate?

    //--------------------
    //MARK: - Properties
    //--------------------
    
    private  let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    
    let persistentContainer: NSPersistentContainer = {
        //Create a Persistent Conainer with a name, name is = as the CoreData Model
        let container = NSPersistentContainer(name: "StarWars")
        //Load the store, by default is a SQLite database
        //it's async 'cose it needs time
        container.loadPersistentStores(completionHandler: { (description, error) in
            if let error = error {
                print("Error setting up Core Data (\(error)).")
            }
        })
        
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil // We don't need undo so set it to nil.
        container.viewContext.shouldDeleteInaccessibleFaults = true
        
        /**
         Merge the changes from other contexts automatically.
         You can also choose to merge the changes by observing NSManagedObjectContextDidSave
         notification and calling mergeChanges(fromContextDidSave notification: Notification)
         */
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        return container
    }()
    
    
    //--------------------
    //MARK: - Person Methods
    //--------------------
    
    ///Fetch all persons from CoreData
    func fetchAllPersonsFromDB(completition: @escaping (PersonsResult) -> Void) {
        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        let sortByName = NSSortDescriptor(key: #keyPath(Person.name), ascending: true)
        fetchRequest.sortDescriptors = [sortByName]
        
        let viewContext = persistentContainer.viewContext
        viewContext.perform {
            do {
                let allPersons = try viewContext.fetch(fetchRequest)
                completition(.success(allPersons))
            } catch {
                completition(.failure(error))
            }
        }
    }
    
    
    ///Fetch all the persons from the web Service (SWAPI)
    func fetchAllPersonsFromAPI(fromURL url:URL? = nil, completion: @escaping (PersonsResult) -> Void) {
        let request: URLRequest
        if let url = url {
            //Make a request with the url passed through
            request = URLRequest(url: url)
        } else {
            //Make a request with the SWAPI url
            let url = SWAPI.allPersonsURL
            request = URLRequest(url: url)
        }
        
        //create an istance of URLSessionTask
        //by giving the session a request and a completion closure
        let task = session.dataTask(with: request) {
            (data, response, error) -> Void in
            
            let res = response as! HTTPURLResponse
            
            //Debug outputs
            print(res.statusCode)
            //----
            
            self.processPersonsRequest(data: data, error: error) { (result, NextPageURL) in
                OperationQueue.main.addOperation {
                    //if there is a next page
                    if let url = NextPageURL {
                        //make another request with the next page url
                        self.fetchAllPersonsFromAPI(fromURL: url, completion: completion)
                    }
                    completion(result)
                }
            }
        }
        //start the web service request
        task.resume()
    }
    
    
    
    ///Process the request to the API, returns a PersonResult object and an URL if there is a "next page" with the next page URL
    private func processPersonsRequest(data: Data?, error: Error?, completion: @escaping (PersonsResult, URL?) -> Void ) {
        guard let jsonData = data else {
            completion(.failure(error!), nil)
            return
        }
        
        //The following request is made in the background queue
        //beacuse it's an expensive task
        
        //create a background context
        persistentContainer.performBackgroundTask { (context) in
            
            //still convert the json data
            let result = SWAPI.persons(fromJSON: jsonData, into: context)
            
            let personResult = result.0
            let nextURL = result.1
            
            //try to save the context (still the background)
            do {
                try context.save()
            } catch {
                print("Error saving the Core Data: \(error).")
                completion(.failure(error), nil)
                return
            }
            
            //now we need to bring the context result into the main queue
            //to do that we extract the object identifier for each entity in the bg queue
            //than we create a reference with the entities in the main queue
            //and we call the completion closure on the referenced entities
            //of the main queue
            
            switch personResult {
            case let .success(persons):
                let personIDs = persons.map { return $0.objectID }
                let viewContext = self.persistentContainer.viewContext
                DispatchQueue.main.async {
                    let viewContextPersons =  personIDs.map { return viewContext.object(with: $0) } as! [Person]
                    completion(.success(viewContextPersons), nextURL)
                }
            case .failure:
                completion(personResult, nextURL)
            }
        }
    }
    
    //--------------------
    //MARK: -  Films Methods
    //--------------------
    
    ///Fetch all films from CoreData
    func fetchAllFilmsFromDB(completition: @escaping (FilmsResult) -> Void) {
        let fetchRequest: NSFetchRequest<Film> = Film.fetchRequest()
        let sortByTitle = NSSortDescriptor(key: #keyPath(Film.title), ascending: true)
        fetchRequest.sortDescriptors = [sortByTitle]
        
        let viewContext = persistentContainer.viewContext
        viewContext.perform {
            do {
                let allFilms = try viewContext.fetch(fetchRequest)
                completition(.success(allFilms))
            } catch {
                completition(.failure(error))
            }
        }
    }
    
    
    
    ///Fetch all the films from the web Service (SWAPI)
    func fetchAllFilmsFromAPI(fromURL url:URL? = nil, completion: @escaping (FilmsResult) -> Void) {
        
        let request: URLRequest
        if let url = url {
            //Make a request with the url passed through
            request = URLRequest(url: url)
        } else {
            //Make a request with the SWAPI url
            let url = SWAPI.allFilmsURL
            request = URLRequest(url: url)
        }
        
        //create an istance of URLSessionTask
        //by giving the session a request and a completion closure
        let task = session.dataTask(with: request) {
            (data, response, error) -> Void in
            
            self.processFilmsRequest(data: data, error: error) { (result, NextPageURL) in
                OperationQueue.main.addOperation {
                    
                    //if there is a next page
                    if let url = NextPageURL {
                        //make another request with the next page url
                        self.fetchAllFilmsFromAPI(fromURL: url, completion: completion)
                    }
                    completion(result)
                }
            }
        }
        //start the web service request
        task.resume()
    }
    
    
    ///Process the request to the API, returns a PersonResult object and an URL if there is a "next page" with the next page URL
    private func processFilmsRequest(data: Data?, error: Error?, completion: @escaping (FilmsResult, URL?) -> Void ) {
        guard let jsonData = data else {
            completion(.failure(error!), nil)
            return
        }
        
        //The following request is made in the background queue
        //beacuse it's an expensive task
        
        //create a background context
        persistentContainer.performBackgroundTask { (context) in
            
            //still convert the json data
            let result = SWAPI.films(fromJSON: jsonData, into: context)
            let filmResult = result.0
            let nextURL = result.1
            
            //try to save the context (still the background)
            do {
                try context.save()
            } catch {
                print("Error saving the Core Data: \(error).")
                completion(.failure(error), nil)
                return
            }
            
            //now we need to bring the context result into the main queue
            //to do that we extract the object identifier for each entity in the bg queue
            //than we create a reference with the entities in the main queue
            //and we call the completion closure on the referenced entities
            //of the main queue
            
            switch filmResult {
            case let .success(films):
                let filmIDs = films.map { return $0.objectID }
                let viewContext = self.persistentContainer.viewContext
                DispatchQueue.main.async {
                    let viewContextFilms =  filmIDs.map { return viewContext.object(with: $0) } as! [Film]
                    completion(.success(viewContextFilms), nextURL)
                }
            case .failure:
                completion(filmResult, nextURL)
            }
        }
    }
    
    
    //--------------------
    //MARK: - Planets Methods
    //--------------------
    
    ///Fetch all planets from CoreData
    func fetchAllPlanetsFromDB(completition: @escaping (PlanetsResult) -> Void) {
        let fetchRequest: NSFetchRequest<Planet> = Planet.fetchRequest()
        let sortByName = NSSortDescriptor(key: #keyPath(Planet.name), ascending: true)
        fetchRequest.sortDescriptors = [sortByName]
        
        let viewContext = persistentContainer.viewContext
        viewContext.perform {
            do {
                let allPlanets = try viewContext.fetch(fetchRequest)
                completition(.success(allPlanets))
            } catch {
                completition(.failure(error))
            }
        }
    }
    
    
    ///Fetch all the planets from the web Service (SWAPI)
    func fetchAllPlanetsFromAPI(fromURL url:URL? = nil, completion: @escaping (PlanetsResult) -> Void) {
        let request: URLRequest
        if let url = url {
            //Make a request with the url passed through
            request = URLRequest(url: url)
        } else {
            //Make a request with the SWAPI url
            let url = SWAPI.allPlanetsURL
            request = URLRequest(url: url)
        }
        
        //create an istance of URLSessionTask
        //by giving the session a request and a completion closure
        let task = session.dataTask(with: request) {
            (data, response, error) -> Void in
            
            let res = response as! HTTPURLResponse
            
            //Debug outputs
            print(res.statusCode)
            //----
            
            self.processPlanetsRequest(data: data, error: error) { (result, NextPageURL) in
                OperationQueue.main.addOperation {
                    //if there is a next page
                    if let url = NextPageURL {
                        //make another request with the next page url
                        self.fetchAllPlanetsFromAPI(fromURL: url, completion: completion)
                    } else {
                        UserDefaults.standard.set(false, forKey: "requestInProgress")
                    }
                    completion(result)
                }
            }
        }
        //start the web service request
        task.resume()
    }
    
    
    
    
    ///Process the request to the API, returns a PlanetsResult object and an URL if there is a "next page" with the next page URL
    private func processPlanetsRequest(data: Data?, error: Error?, completion: @escaping (PlanetsResult, URL?) -> Void ) {
        guard let jsonData = data else {
            completion(.failure(error!), nil)
            return
        }
        
        //The following request is made in the background queue
        //beacuse it's an expensive task
        
        //create a background context
        persistentContainer.performBackgroundTask { (context) in
            
            //still convert the json data
            let result = SWAPI.planets(fromJSON: jsonData, into: context)
            
            let planetResult = result.0
            let nextURL = result.1
            
            //try to save the context (still the background)
            do {
                try context.save()
            } catch {
                print("Error saving the Core Data: \(error).")
                completion(.failure(error), nil)
                return
            }
            
            //now we need to bring the context result into the main queue
            //to do that we extract the object identifier for each entity in the bg queue
            //than we create a reference with the entities in the main queue
            //and we call the completion closure on the referenced entities
            //of the main queue
            
            switch planetResult {
            case let .success(planets):
                let planetIDs = planets.map { return $0.objectID }
                let viewContext = self.persistentContainer.viewContext
                DispatchQueue.main.async {
                    let viewContextPlanets =  planetIDs.map { return viewContext.object(with: $0) } as! [Planet]
                    completion(.success(viewContextPlanets), nextURL)
                }
                
            case .failure:
                completion(planetResult, nextURL)
            }
        }
    }

    // Helpers
    
    func loadDataForPlanets(completion: @escaping () -> Void) {

        //ensure all changes are commited
        try? self.persistentContainer.viewContext.save()
        
        // will be set to false later when no nextURL exist
        UserDefaults.standard.set(true, forKey: "requestInProgress")

        self.fetchAllPlanetsFromAPI { (planetResult) in
            print("planets downloaded")
            if !UserDefaults.standard.bool(forKey: "requestInProgress") {
                completion()
            }
        }

        self.fetchAllPersonsFromAPI() { (personResult) in
            print("characters downloaded")
        }
        
        self.fetchAllFilmsFromAPI { (filmResult) in
            print("films downloaded")
        }
        
    }
    
    func deleteAllData(_ entity:String) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
        fetchRequest.returnsObjectsAsFaults = false
        do {
            let results = try persistentContainer.viewContext.fetch(fetchRequest)
            for object in results {
                guard let objectData = object as? NSManagedObject else {continue}
                persistentContainer.viewContext.delete(objectData)
            }
        } catch let error {
            print("Detele all data in \(entity) error :", error)
        }
    }
    
    // fetchedResultsController
    lazy var fetchedResultsController: NSFetchedResultsController<Planet> = {
        
        let fetchRequest = NSFetchRequest<Planet>(entityName:"Planet")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending:true)]
        
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                    managedObjectContext: persistentContainer.viewContext,
                                                    sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = fetchedResultsControllerDelegate
        
        do {
            try controller.performFetch()
        } catch {
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
        
        return controller
    }()

    
}

