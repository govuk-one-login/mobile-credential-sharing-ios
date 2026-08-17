extension MockCredential {
    static var allMocks: [MockCredential] {
        [
            .janeDoe(),
            .janeDoeSigningFailure(),
            .janeDoeAuthCancelledOnce(),
            .janeDoeUnfulfillable()
        ]
    }
}
