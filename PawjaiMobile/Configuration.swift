//
//  Configuration.swift
//  PawjaiMobile
//
//  Created by Purin Buriwong on 3/9/2568 BE.
//

import Foundation

struct Configuration {
    // STG
    // Supabase - Must match backend for JWT verification
    // static let supabaseURL = "https://vujtupxhnekyxxidzicu.supabase.co"
    // static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ1anR1cHhobmVreXh4aWR6aWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk4MTQ4NDEsImV4cCI6MjA3NTM5MDg0MX0.nVUCEHTdhW9f_GGNDxqklBmpsjPDlyHLiIYD9pO4keI"
    // // URLs
    // static let redirectURL = "pawjai://auth-callback"
    // static let webAppURL = "https://stg.pawjai.co"
    // static let backendApiURL = "https://pawjai-be-develop.up.railway.app"


    // PROD
    // Supabase - Must match backend for JWT verification
    static let supabaseURL = "https://mdbrwfipxtnshqdrkdhp.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1kYnJ3ZmlweHRuc2hxZHJrZGhwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkzOTY5MTgsImV4cCI6MjA2NDk3MjkxOH0.-nRN7WuC4vk-8ggo5WCwmYxGeanDW2hIBUk_riKh9Kg"
    // URLs
    static let redirectURL = "pawjai://auth-callback"
    static let webAppURL = "https://pawjai.co"
    static let backendApiURL = "https://pawjai-be-production.up.railway.app"
    
}
