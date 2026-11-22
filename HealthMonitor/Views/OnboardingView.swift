import SwiftUI

/// First launch: a plain explanation of what the app reads and why, then
/// one button that triggers the system's HealthKit permission screen.
///
/// Note: HealthKit never tells the app which types were allowed, so the
/// app treats "authorization requested" as done and checks its data on
/// the next screen.
struct OnboardingView: View {
    @Environment(HealthStore.self) private var healthStore
    @AppStorage("didRequestHealthAuthorization") private var didRequestHealthAuthorization = false
    @State private var isRequesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()

            Image(systemName: "heart.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("HealthMonitor")
                .font(.largeTitle)
                .bold()

            Text("This app reads your heart rate, heart rate variability, and sleep from Apple Health, compares them with your own usual range, and lets you know when something stays off for a few days.")
                .font(.body)

            VStack(alignment: .leading, spacing: 8) {
                Label("Your data never leaves this phone.", systemImage: "lock.fill")
                Label("No account, no server, no diagnosis.", systemImage: "checkmark.circle.fill")
                Label("You can turn off access any time in the Health app.", systemImage: "hand.raised.fill")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Spacer()

            Button {
                isRequesting = true
                Task {
                    _ = await healthStore.requestAuthorization()
                    // Ask for alert permission only after Health access, so
                    // the user is not hit with two system prompts at once.
                    _ = await NotificationService.shared.requestAuthorization()
                    didRequestHealthAuthorization = true
                    isRequesting = false
                }
            } label: {
                Text("Connect Apple Health")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRequesting)

            if !healthStore.isHealthDataAvailable {
                Text("Health data is not available on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
