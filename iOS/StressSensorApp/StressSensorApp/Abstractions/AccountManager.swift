//
//  AccountManager.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 04/03/2019.
//  Copyright © 2019 AssistiveTech KTH. All rights reserved.
//

import UIKit
import ResearchKit
import PromiseKit


class LoginViewController: ORKLoginStepViewController {
    override func forgotPasswordButtonTapped() {
        let alert = UIAlertController(
            title: "Password reset",
            message: "Please contact Assistive Technology KTH to request a password reset!",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}


class AccountManager: NSObject {

    fileprivate var registrationTask: ORKOrderedTask?
    fileprivate var verificationTask: ORKOrderedTask?
    fileprivate var loginTask: ORKOrderedTask?
    fileprivate weak var parentController: UIViewController?

    private override init() { super.init() }
    static let shared = AccountManager()

    private func present(task: ORKOrderedTask, on viewController: UIViewController) {
        let taskVC = ORKTaskViewController(task: task, taskRun: nil)
        taskVC.delegate = self
        parentController = viewController
        viewController.present(taskVC, animated: true, completion: nil)
    }

    func presentRegistrationForm(on viewController: UIViewController) {

        let registrationStep = ORKRegistrationStep(
            identifier: "registrationStep",
            title: "Account Registration",
            text: "Please register at this point.",
            options: [.includeDOB, .includeGivenName, .includeFamilyName, .includeGender]
        )

        registrationTask = ORKOrderedTask(identifier: "registrationTask", steps: [registrationStep])
        present(task: registrationTask!, on: viewController)
    }

    func presentLoginForm(on viewController: UIViewController) {

        let loginStep = ORKLoginStep(
            identifier: "loginStep",
            title: "Login",
            text: "Please login with your credentials.",
            loginViewControllerClass: LoginViewController.self
        )

        loginTask = ORKOrderedTask(identifier: "loginTask", steps: [loginStep])
        present(task: loginTask!, on: viewController)
    }

    private func presentVerificationStep(on viewController: UIViewController) {
        fatalError("Not implemented")
        /*
        let verificationStep = ORKVerificationStep(
            identifier: "verificationStep",
            text: "Please verify your email.",
            verificationViewControllerClass: VerificationViewController.self
        )
        verificationTask = ORKOrderedTask(identifier: "verificationTask", steps: [verificationStep])
        present(task: verificationTask!, on: viewController)
        */
    }

    fileprivate func tryToRegister(with formResult: RegistrationFormResult, vc: ORKTaskViewController) {
        let loadingAlert = UIAlertController(title: "Loading...", message: nil, preferredStyle: .alert)
        vc.present(loadingAlert, animated: true, completion: nil)

        let credentials = UserCredentials(email: formResult.email, password: formResult.password)
        let signUp = Firebase.signUp(credentials)
        signUp.get { userID in
            mainStore.safeDispatch(Actions.UpdateUserID(userID: userID))
        }.then { userID in
            Firebase.initUser(withID: userID, info: formResult.asUserInfo())
        }.done { userInfo in
            mainStore.safeDispatch(Actions.UpdateUserInfo(userInfo: userInfo))
            credentials.save()
        }.ensureThen {
            loadingAlert.dismiss()
        }.then {
            vc.dismiss()
        }.catch { error in
            vc.presentGenericError(error.localizedDescription)
        }
    }

    private func loginProcedure(credentials: UserCredentials, vc: UIViewController) -> Promise<Void> {
        let loadingAlert = UIAlertController(title: "Loading...", message: nil, preferredStyle: .alert)
        vc.present(loadingAlert, animated: true, completion: nil)

        return Firebase.signIn(credentials).get { userID in
            mainStore.safeDispatch(Actions.UpdateUserID(userID: userID))
        }.then { userID in
            Firebase.getUserInfo(withID: userID)
        }.done { userInfo in
            mainStore.safeDispatch(Actions.UpdateUserInfo(userInfo: userInfo))
            credentials.save()
        }.ensureThen {
            loadingAlert.dismiss()
        }
    }

    fileprivate func tryToLogin(on vc: ORKTaskViewController, formResult: LoginFormResult) {
        let credentials = UserCredentials(email: formResult.email, password: formResult.password)
        let login = loginProcedure(credentials: credentials, vc: vc)
        login.then {
            vc.dismiss()
        }.catch { error in
            vc.presentGenericError(error.localizedDescription)
        }
    }

    func tryToLogin(on presentingViewController: UIViewController) {
        if let email = mainStore.state.user.userInfo?.email, let credentials = UserCredentials.load(withEmail: email) {
            let login = loginProcedure(credentials: credentials, vc: presentingViewController)
            login.catch { error in
                presentingViewController.presentGenericError(error.localizedDescription)
            }
        } else {
            let alert = UIAlertController(title: "Login required!", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Login", style: .default, handler: { [weak self] _ in
                self?.presentLoginForm(on: presentingViewController)
            }))
            alert.addAction(UIAlertAction(title: "Register", style: .default, handler: { [weak self] _ in
                self?.presentRegistrationForm(on: presentingViewController)
            }))
            alert.addAction(UIAlertAction(title: "Continue anonymously", style: .destructive, handler: nil))
            presentingViewController.present(alert, animated: true, completion: nil)
        }
    }

    private func presentDataDeletionAlert(on presentingViewController: UIViewController, afterLogout: Bool, completion: ((Bool) -> ())?) {
        func confirm(_ action: UIAlertAction) {
            StressModel.main.clear()
            EnergyModel.main.clear()
            QuadrantModel.main.clear()
            completion?(true)
        }
        let alert = UIAlertController(
            title: afterLogout ? "Delete local data?" : "Are you sure?",
            message: "You're about to delete all collected data stored locally. New predictions will require training a new model.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in completion?(false) }))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: confirm))
        presentingViewController.present(alert, animated: true, completion: nil)
    }

    func presentDataDeletionAlert(on presentingViewController: UIViewController, completion: ((Bool) -> ())?) {
        presentDataDeletionAlert(on: presentingViewController, afterLogout: false, completion: completion)
    }

    func presentLogoutAlert(on presentingViewController: UIViewController) {
        func confirm(_ action: UIAlertAction) {
            mainStore.safeDispatch(Actions.ClearUserState())
            presentDataDeletionAlert(on: presentingViewController, afterLogout: true, completion: nil)
        }
        let alert = UIAlertController(
            title: "Are you sure?",
            message: "You're about to logout from your account.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Logout", style: .destructive, handler: confirm))
        presentingViewController.present(alert, animated: true, completion: nil)
    }

    func presentManageAccountAlert(on presentingViewController: UIViewController) {
        if mainStore.state.user.userInfo == nil {
            // Login / Register
            let alert = UIAlertController(
                title: "Do you have an account?",
                message: "You can choose to login to an existing account or register as a new user.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Login", style: .default, handler: { [weak self] _ in
                self?.presentLoginForm(on: presentingViewController)
            }))
            alert.addAction(UIAlertAction(title: "Register", style: .default, handler: { [weak self] _ in
                self?.presentRegistrationForm(on: presentingViewController)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            presentingViewController.present(alert, animated: true, completion: nil)
        } else {
            // Logout
            presentLogoutAlert(on: presentingViewController)
        }
    }
}


extension AccountManager: ORKTaskViewControllerDelegate {

    fileprivate struct RegistrationFormResult {
        let email: String
        let password: String
        let firstName: String
        let lastName: String
        let gender: String
        let dateOfBirth: String

        init?(_ stepResult: ORKStepResult) {

            if let email = (stepResult.result(forIdentifier: ORKRegistrationFormItemIdentifierEmail) as? ORKTextQuestionResult)?.textAnswer,
                let password = (stepResult.result(forIdentifier: ORKRegistrationFormItemIdentifierPassword) as? ORKTextQuestionResult)?.textAnswer,
                let firstName = (stepResult.result(forIdentifier: ORKRegistrationFormItemIdentifierGivenName) as? ORKTextQuestionResult)?.textAnswer,
                let lastName = (stepResult.result(forIdentifier: ORKRegistrationFormItemIdentifierFamilyName) as? ORKTextQuestionResult)?.textAnswer,
                let gender = (stepResult.result(forIdentifier: ORKRegistrationFormItemIdentifierGender) as? ORKChoiceQuestionResult)?.choiceAnswers?.first as? String,
                let dateOfBirth = (stepResult.result(forIdentifier: ORKRegistrationFormItemIdentifierDOB) as? ORKDateQuestionResult)?.dateAnswer {
                self.email = email
                self.password = password
                self.firstName = firstName
                self.lastName = lastName
                self.gender = gender
                self.dateOfBirth = ISO8601DateFormatter().string(from: dateOfBirth)
            } else {
                return nil
            }
        }

        func asUserInfo() -> UserInfo {
            return UserInfo(
                clearance: .user,
                email: email,
                firstName: firstName,
                lastName: lastName,
                gender: gender,
                dateOfBirth: dateOfBirth
            )
        }
    }

    fileprivate struct LoginFormResult {
        let email: String
        let password: String

        init?(_ stepResult: ORKStepResult) {

            if let email = (stepResult.result(forIdentifier: ORKLoginFormItemIdentifierEmail) as? ORKTextQuestionResult)?.textAnswer,
                let password = (stepResult.result(forIdentifier: ORKLoginFormItemIdentifierPassword) as? ORKTextQuestionResult)?.textAnswer {
                self.email = email
                self.password = password
            } else {
                return nil
            }
        }
    }

    func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {
        guard let taskID = taskViewController.task?.identifier else { return }

        if taskID == registrationTask?.identifier {
            if reason == .completed {
                let stepID = registrationTask?.steps.first?.identifier
                let stepResult = taskViewController.result.stepResult(forStepIdentifier: stepID!)!
                tryToRegister(with: RegistrationFormResult(stepResult)!, vc: taskViewController)
            } else {
                taskViewController.dismiss(animated: true, completion: nil)
            }
        } else if taskID == loginTask?.identifier {
            if reason == .completed {
                let stepID = loginTask?.steps.first?.identifier
                let stepResult = taskViewController.result.stepResult(forStepIdentifier: stepID!)!
                tryToLogin(on: taskViewController, formResult: LoginFormResult(stepResult)!)
            } else {
                taskViewController.dismiss(animated: true, completion: nil)
            }
        }
    }
}
