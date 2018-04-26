
struct Secret {
    static let firebaseEmail = "" // EMAIL HERE
    static let firebasePassword = "" // PASSWORD HERE
    static var isValid = !firebaseEmail.isEmpty && !firebasePassword.isEmpty
}
