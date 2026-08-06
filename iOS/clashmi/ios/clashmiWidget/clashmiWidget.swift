//
//  clashmiWidget.swift
//  clashmiWidget
//
//  Created by user on 2026/1/19.
//

import WidgetKit
import SwiftUI
import NetworkExtension

struct clashmiStatusEntry: TimelineEntry {
    let date: Date
    let isRunning: Bool
}

struct clashmiStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> clashmiStatusEntry {
        clashmiStatusEntry(date: Date(), isRunning: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (clashmiStatusEntry) -> Void) {
        completion(clashmiStatusEntry(date: Date(), isRunning: false))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<clashmiStatusEntry>) -> Void) {
        let now = Date()
        VpnServiceHandler.shared.getState { state in
            let raw = (state["status"] as? Int) ?? NEVPNStatus.invalid.rawValue
            let status = NEVPNStatus(rawValue: raw) ?? .invalid
            let isRunning = status == .connecting || status == .connected || status == .reasserting
            let entry = clashmiStatusEntry(date: now, isRunning: isRunning)
            let next = Calendar.current.date(byAdding: .minute, value: 1, to: now) ?? now.addingTimeInterval(60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

struct clashmiStatusWidget: Widget {
    static let kind: String = "com.nebula.clashmi.clashmiWidget.Status"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: clashmiStatusProvider()) { entry in
            clashmiStatusView(entry: entry)
        }
        .configurationDisplayName("Clash Mi")
        .description("Show Clash Mi VPN status")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct clashmiStatusView: View {
    let entry: clashmiStatusEntry

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: entry.isRunning ? "shield.fill" : "shield.slash")
                .font(.title2)
                .foregroundStyle(entry.isRunning ? .green : .secondary)
            Text(entry.isRunning ? "ON" : "OFF")
                .font(.headline)
                .foregroundStyle(entry.isRunning ? .green : .secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
