//
//  EditViewController+OpenAI.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/23/25.
//

import Foundation

extension EditViewController {
    
    // MARK: - Open AI Lookup
    @IBAction func fetchAIResponse(_ sender: Any) {
        let softwareTitle = fieldName.stringValue
        guard !softwareTitle.isEmpty else {
            Logger.logApp("Software title is empty.")
            return
        }
        
        let prompt = "What is \(softwareTitle) for macOS?"
        fetchAIResponse(prompt: prompt) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.fieldLabelDescription.string = response
                case .failure(let error):
                    self?.fieldLabelDescription.string = "Failed to fetch response: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func fetchAIResponse(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        let endpoint = "https://api.openai.com/v1/chat/completions"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Updated payload for chat completions
        let parameters: [String: Any] = [
            "model": "gpt-3.5-turbo", // Use "gpt-4" if preferred
            "messages": [
                ["role": "system", "content": "You are a helpful assistant."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 150,
            "temperature": 0.7
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: parameters, options: [])
            request.httpBody = jsonData
//            print("Request payload: \(String(data: jsonData, encoding: .utf8) ?? "Invalid JSON")")
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: 0, userInfo: nil)))
                return
            }
            
            // Debug raw response
//            if let rawResponse = String(data: data, encoding: .utf8) {
//                print("Raw response: \(rawResponse)")
//            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    completion(.failure(NSError(domain: "Invalid response", code: 0, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }


}
