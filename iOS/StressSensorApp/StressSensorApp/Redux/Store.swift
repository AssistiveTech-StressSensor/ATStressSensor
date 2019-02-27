//
//  Store.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 25/02/2019.
//  Copyright © 2019 AssistiveTech KTH. All rights reserved.
//

import Foundation
import ReSwift


struct DeviceState: StateType {
    var linkStatus: DeviceLinkStatus = .disconnected
    var authenticated = false
    var batteryLevel: Float?
}

struct UserState: StateType {
    var userID: String? = nil
    var userClearance: UserClearance = .user
}

struct DebugOptionsState: StateType {
    var disableCooldown = false
    var useFakeSnapshots = false
    var addNoiseToSignals = false
}

struct AppState: StateType {
    var user = UserState()
    var device = DeviceState()
    var debug = DebugOptionsState()
}


protocol UserAction: Action {}
protocol DebugAction: Action {}
protocol DeviceAction: Action {}

struct Actions {
    struct ChangeUserID: UserAction { let userID: String? }
    struct ChangeUserClearance: UserAction { let userClearance: UserClearance }
    struct DisableCooldown: DebugAction { let value: Bool }
    struct UseFakeSnapshots: DebugAction { let value: Bool }
    struct AddNoiseToSignals: DebugAction { let value: Bool }
}

struct DeviceActions {
    struct SetLinkStatus: DeviceAction { let value: DeviceLinkStatus }
    struct SetAuthenticated: DeviceAction { let value: Bool }
    struct SetBatteryLevel: DeviceAction { let value: Float? }
    struct InvalidateDeviceInfo: DeviceAction {}
}


private func deviceReducer(action: DeviceAction, state: DeviceState?) -> DeviceState {
    var state = state ?? DeviceState()

    switch action {
    case let action as DeviceActions.SetLinkStatus:
        state.linkStatus = action.value
    case let action as DeviceActions.SetAuthenticated:
        state.authenticated = action.value
    case let action as DeviceActions.SetBatteryLevel:
        state.batteryLevel = action.value
    case _ as DeviceActions.InvalidateDeviceInfo:
        state.batteryLevel = nil
    default:
        break
    }

    return state
}


private func debugOptionsReducer(action: DebugAction, state: DebugOptionsState?) -> DebugOptionsState {
    var state = state ?? DebugOptionsState()

    switch action {
    case let action as Actions.DisableCooldown:
        state.disableCooldown = action.value
    case let action as Actions.UseFakeSnapshots:
        state.useFakeSnapshots = action.value
    case let action as Actions.AddNoiseToSignals:
        state.addNoiseToSignals = action.value
    default:
        break
    }

    return state
}


private func userReducer(action: UserAction, state: UserState?) -> UserState {
    var state = state ?? UserState()

    switch action {
    case let action as Actions.ChangeUserID:
        state.userID = action.userID
    case let action as Actions.ChangeUserClearance:
        state.userClearance = action.userClearance
    default:
        break
    }

    return state
}


private func reducer(action: Action, state: AppState?) -> AppState {
    var state = state ?? AppState()
    switch action {
    case let action as UserAction:
        state.user = userReducer(action: action, state: state.user)
    case let action as DeviceAction:
        state.device = deviceReducer(action: action, state: state.device)
    case let action as DebugAction:
        state.debug = debugOptionsReducer(action: action, state: state.debug)
    default:
        break
    }
    return state
}


let mainStore = Store<AppState>(
    reducer: reducer,
    state: nil
)


extension Store {
    func safeDispatch(_ action: Action) {
        if Thread.isMainThread {
            self.dispatch(action)
        } else {
            DispatchQueue.main.sync { self.dispatch(action) }
        }
    }
}
