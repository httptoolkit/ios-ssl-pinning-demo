import SwiftUI

struct ContentView: View {
    
    @StateObject var viewModel = RequestViewModel()
    
    let SPACING = 15.0

    var body: some View {
        VStack {
            Text("SSL Pinning Demo")
                .font(.largeTitle)
                .padding(.top)
            
            GeometryReader { geometry in
                ScrollView(.vertical) {
                    VStack(spacing: SPACING) {
                        ForEach(viewModel.unpinnedRequests) { request in
                            RequestButtonView(request: request, viewModel: viewModel)
                        }
                        
                        Divider()
                            .background(Color.gray)
                            .padding(.horizontal)

                        ForEach(viewModel.pinnedRequests) { request in
                            RequestButtonView(request: request, viewModel: viewModel)
                        }
                    }
                    .frame(
                        minWidth: geometry.size.width - SPACING*2,
                        minHeight: geometry.size.height - SPACING*2,
                        alignment: .center
                    )
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct RequestButtonView: View {
    
    @ObservedObject var request: BaseHTTPRequest
    var viewModel: RequestViewModel

    var body: some View {
        Button(action: {
            if (request.isAvailable()) {
                viewModel.sendRequest(request)
            }
        }) {
            HStack {
                Spacer().frame(width: 16)
                
                if request.status == .success {
                    Image(systemName: "checkmark.circle")
                } else if request.status == .failure {
                    Image(systemName: "xmark.circle")
                } else {
                    // Invisible placeholder to maintain alignment
                    Image(systemName: "circle").opacity(0)
                }

                Spacer()

                if request.isLoading {
                    ProgressView()
                } else if !request.isAvailable() {
                    VStack {
                        Text(request.name)
                        Text("(Not available)")
                    }
                } else {
                    Text(request.name)
                }

                Spacer()
                
                // Matching placeholder, so we end up centered
                Image(systemName: "circle").opacity(0)
                Spacer().frame(width: 16)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .disabled(!request.isAvailable())
        }
        .background(
            request.isAvailable() == false
                ? Color.gray
            : request.status == .none
                ? Color.purple
            : request.status == .success
                ? Color.green
            // Failure:
                : Color.red
        )
        .foregroundColor(.white)
        .cornerRadius(8)
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
