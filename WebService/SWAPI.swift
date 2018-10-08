//
//  SWAPI.swift
//  StarWars
//
//  Created by Jérôme Haegeli on 06.10.18.
//  Copyright © 2018 Jeko. All rights reserved.
//

import Foundation
import CoreData

// Defines the SWAPI errors
enum SWAPIError: Error {
    case invalidJSONData
    case invalidURL
}

// Defines the path for a certain resource
enum Method: String {
    case allPersons = "people/"
    case allFilms = "films/"
    case allPlanets = "planets/"
}

// SWAPI struct works as intermediate between the client and the SWAPI Web Service
struct SWAPI {
    
    //--------------------
    //MARK: - Properties
    //--------------------
    
    /// The base url for any request to the API
    private static let baseURLString = "https://swapi.co/api/"
    
    // The date formatter to build the date from the iso8601 format
    private static let dateFormatterISO8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter
    }()
    
    private static let dateFormatterForReleaseDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    static var allFilmsURL: URL {
        return SWAPIURL(method: .allFilms)
    }
    
    static var allPersonsURL: URL {
        return SWAPIURL(method: .allPersons)
    }
    
    static var allPlanetsURL: URL {
        return SWAPIURL(method: .allPlanets)
    }
    
    //--------------------
    //MARK: -  General Methods
    //--------------------

    /// Method used to build the endpoint url
    private static func SWAPIURL(method: Method) -> URL {
        let baseURL = URL(string: baseURLString)!
        let finalURL = URL(string: method.rawValue, relativeTo: baseURL)!
        return finalURL
    }
    
    /// Method used to build the url for the next page
    static func nextPageURL(endpointURL: URL, withCurrentPage page: Int) -> URL {
        var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: true)!
        var queryItems = [URLQueryItem]()
        let queryItem = URLQueryItem(name: "page", value: "\(page+1)")
        queryItems.append(queryItem)
        components.queryItems = queryItems
        return components.url!
    }
    
    //--------------------
    //MARK: -  Persons Methods
    //--------------------
    
    ///Transform a bunch of data persons into an array of Persons. Returns an array of Persons with the next page URL
    static func persons(fromJSON data: Data, into context: NSManagedObjectContext) -> (PersonsResult, URL?) {
        do {
            //convert the jsonData into a jsonObject
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            
            guard
                let jsonDictionary = jsonObject as? [AnyHashable : Any],
                let personsArray = jsonDictionary["results"] as? [[String : Any]] else {
                    
                    //The JSON structure doesn't match our expectations
                    return (.failure(SWAPIError.invalidJSONData), nil)
            }
            
            var finalPersons = [Person]()
            for personJSON in personsArray {
                
                if let person = person(fromJSON: personJSON, into: context) {
                    finalPersons.append(person)
                }
            }
            
            if finalPersons.isEmpty && !personsArray.isEmpty {
                //We weren't able to parse any of the personss
                //Maybe the JSON format for persons has changed
                return (.failure(SWAPIError.invalidJSONData), nil)
            }
            
            //fetching the url for the next page of persons
            guard let urlString = jsonDictionary["next"] as? String, let url = URL(string: urlString) else {
                //if the next url points to nil
                return (.success(finalPersons), nil)
            }
            return (.success(finalPersons), url)
        } catch let error {
            return (.failure(error), nil)
        }
    }
    
    ///Transform the json person into a Person and return it.
    private static func person(fromJSON json: [String : Any], into context: NSManagedObjectContext) -> Person? {
        guard
            let name = json["name"] as? String,
            let birth_year = json["birth_year"] as? String,
            let eye_color = json["eye_color"] as? String,
            let gender = json["gender"] as? String,
            let hair_color = json["hair_color"] as? String,
            let skin_color = json["skin_color"] as? String,
            let heightString = json["height"] as? String,
            let massString = json["mass"] as? String,
            let editedString = json["edited"] as? String,
            let edited = dateFormatterISO8601.date(from: editedString),
            let homeworld_url = json["homeworld"] as? String,
            let film_urls = json["films"] as? [String],
            let url = json["url"] as? String else {
                
                //Don't have enough information to construct a Person
                print("Don't have enough information to construct a Person")
                return nil
        }
        
        //Need to know if we have already created a Person with the same name in the Core Data
        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        let predicate = NSPredicate(format: "\(#keyPath(Person.name)) == %@", name)
        fetchRequest.predicate = predicate
        
        var fetchedPersons: [Person]?
        context.performAndWait {
            fetchedPersons = try? fetchRequest.execute()
        }
        //The person already exist in Core Data? Does it have the same edited date?
        if let existingPerson = fetchedPersons?.first, existingPerson.edited == (edited) {
            //Yes, so return it
            return existingPerson
        }
        //No, so create it and we return it
        var person: Person!
        //use performAndWait (Synch vs perform Asynch) beacue
        //it has to return the person genereted into insert operation
        context.performAndWait {
            person = Person(context: context)
            person.name = name
            person.url = url
            person.birth_year = birth_year
            person.eye_color = eye_color
            person.gender = gender
            person.hair_color = hair_color
            person.skin_color = skin_color
            person.homeworld_url = homeworld_url
            person.film_urls = film_urls as NSObject
            
            if let height = Double(heightString) {
                person.height = height
            }
            if let mass = Double(massString) {
                person.mass = mass
            }
            person.edited = edited
            
        }
        return person
    }
    
    //--------------------
    //MARK: -  Films Methods
    //--------------------
    
    ///Transform a bunch of data films into an array of Films. Returns an array of Films with the next page URL
    static func films(fromJSON data: Data, into context: NSManagedObjectContext) -> (FilmsResult, URL?) {
        do {
            //convert the jsonData into a jsonObject
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            
            guard
                let jsonDictionary = jsonObject as? [AnyHashable : Any],
                let filmsArray = jsonDictionary["results"] as? [[String : Any]] else {
                    
                    //The JSON structure doesn't match our expectations
                    return (.failure(SWAPIError.invalidJSONData), nil)
            }
            
            var finalFilms = [Film]()
            for filmJSON in filmsArray {
                if let film = film(fromJSON: filmJSON, into: context) {
                    finalFilms.append(film)
                }
            }
            
            if finalFilms.isEmpty && !filmsArray.isEmpty {
                //Weren't able to parse any of the films
                //Maybe the JSON format for films has changed
                return (.failure(SWAPIError.invalidJSONData), nil)
            }
            
            //fetching the url for the next page of films
            guard let urlString = jsonDictionary["next"] as? String, let url = URL(string: urlString) else {
                //if the next url points to nil
                return (.success(finalFilms), nil)
            }
            return (.success(finalFilms), url)
        } catch let error {
            return (.failure(error), nil)
        }
    }
    
    
    ///Transform the json film into a Film and return it.
    private static func film(fromJSON json: [String : Any], into context: NSManagedObjectContext) -> Film? {
        
        guard
            let title = json["title"] as? String,
            
            let producer = json["producer"] as? String,
            let opening_crawl = json["opening_crawl"] as? String,
            let director = json["director"] as? String,
            let episode_id = json["episode_id"] as? Int16,
            let editedString = json["edited"] as? String,
            let edited = dateFormatterISO8601.date(from: editedString),
            let release_dateString = json["release_date"] as? String,
            let character_urls = json["characters"] as? [String],
            let planet_urls = json["planets"] as? [String],
            let url = json["url"] as? String else {
                
                //Don't have enough information to construct a film
                print("Don't have enough information to construct a film")
                return nil
        }
        
        //Need to know if we have already created a Film with the same title in the Core Data
        let fetchRequest: NSFetchRequest<Film> = Film.fetchRequest()
        let predicate = NSPredicate(format: "\(#keyPath(Film.title)) == %@", title)
        fetchRequest.predicate = predicate
        
        var fetchedFilms: [Film]?
        context.performAndWait {
            fetchedFilms = try? fetchRequest.execute()
        }
        //The film already exist in Core Data? Does it have the same edited date?
        if let existingFilm = fetchedFilms?.first, existingFilm.edited == (edited)  {
            //yes, so return it
            return existingFilm
        }
        //No, so create it and we return it
        var film: Film!
        //use performAndWait (Synch vs perform Asynch) beacue
        //it has to return the film genereted into insert operation
        context.performAndWait {
            film = Film(context: context)
            film.title = title
            film.url = url
            film.director = director
            film.producer = producer
            film.opening_crawl = opening_crawl
            film.episode_id = episode_id
            film.edited = edited
            film.character_urls = character_urls as NSObject
            film.planet_urls = planet_urls as NSObject
            
            if let release_date = dateFormatterForReleaseDate.date(from: release_dateString) {
                
                film.release_date = release_date
            }
            
        }
        return film
    }
    
    //--------------------
    //MARK: -  Planets Methods
    //--------------------
    
    ///Transform a bunch of data planets into an array of Planets. Returns an array of Planets with the next page URL
    static func planets(fromJSON data: Data, into context: NSManagedObjectContext) -> (PlanetsResult, URL?) {
        do {
            //convert the jsonData into a jsonObject
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            
            guard
                let jsonDictionary = jsonObject as? [AnyHashable : Any],
                let planetsArray = jsonDictionary["results"] as? [[String : Any]] else {
                    
                    //The JSON structure doesn't match our expectations
                    return (.failure(SWAPIError.invalidJSONData), nil)
            }
            
            var finalPlanets = [Planet]()
            for planetJSON in planetsArray {
                
                if let planet = planet(fromJSON: planetJSON, into: context) {
                    finalPlanets.append(planet)
                }
            }
            
            if finalPlanets.isEmpty && !planetsArray.isEmpty {
                //We weren't able to parse any of the planets
                //Maybe the JSON format for planets has changed
                return (.failure(SWAPIError.invalidJSONData), nil)
            }
            
            //fetching the url for the next page of planets
            guard let urlString = jsonDictionary["next"] as? String, let url = URL(string: urlString) else {
                //if the next url points to nil
                return (.success(finalPlanets), nil)
            }
            return (.success(finalPlanets), url)
        } catch let error {
            return (.failure(error), nil)
        }
    }
    
    ///Transform the json planet into a Planet and return it.
    private static func planet(fromJSON json: [String : Any], into context: NSManagedObjectContext) -> Planet? {
        guard
            let name = json["name"] as? String,
            let climate = json["climate"] as? String,
            let terrain = json["terrain"] as? String,
            let diameterString = json["diameter"] as? String,
            let gravityString = json["gravity"] as? String,
            let orbital_periodString = json["orbital_period"] as? String,
            let populationString = json["population"] as? String,
            let rotation_periodString = json["rotation_period"] as? String,
            let surface_waterString = json["surface_water"] as? String,
            let editedString = json["edited"] as? String,
            let edited = dateFormatterISO8601.date(from: editedString),
            let resident_urls = json["residents"] as? [String],
            let film_urls = json["films"] as? [String],
            let url = json["url"] as? String else {
                
                //Don't have enough information to construct a Planet
                print("Don't have enough information to construct a Planet")
                return nil
        }
        
        //Need to know if we have already created a Planet with the same name in the Core Data
        let fetchRequest: NSFetchRequest<Planet> = Planet.fetchRequest()
        let predicate = NSPredicate(format: "\(#keyPath(Planet.name)) == %@", name)
        fetchRequest.predicate = predicate
        
        var fetchedPlanets: [Planet]?
        context.performAndWait {
            fetchedPlanets = try? fetchRequest.execute()
        }
        //The planet already exist in Core Data? Does it have the same edited date?
        if let existingPlanet = fetchedPlanets?.first, existingPlanet.edited == (edited) {
            //Yes, so return it
            return existingPlanet
        }
        //No, so create it and we return it
        var planet: Planet!
        //use performAndWait (Synch vs perform Asynch) beacue
        //it has to return the planet genereted into insert operation
        context.performAndWait {
            planet = Planet(context: context)
            planet.name = name
            planet.terrain = terrain
            planet.climate = climate
            planet.url = url
            planet.resident_urls = resident_urls as NSObject
            planet.film_urls = film_urls as NSObject
            
            if let diameter = Int32(diameterString) {
                planet.diameter = diameter
            }
            if let gravity = Double(gravityString) {
                planet.gravity = gravity
            }
            if let orbital_period = Int16(orbital_periodString) {
                planet.orbital_period = orbital_period
            }
            if let population = Int64(populationString) {
                planet.population = population
            }
            if let rotation_period = Int16(rotation_periodString) {
                planet.rotation_period = rotation_period
            }
            if let surface_water = Double(surface_waterString) {
                planet.surface_water = surface_water
            }
            
            planet.edited = edited
            
        }
        return planet
    }

}
