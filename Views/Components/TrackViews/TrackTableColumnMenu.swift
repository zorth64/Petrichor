import SwiftUI

struct TrackTableColumnMenu: View {
    @StateObject private var columnManager = ColumnVisibilityManager.shared

    var body: some View {
        Menu {
            ForEach(TrackTableColumn.allColumns, id: \.self) { column in
                Toggle(column.displayName, isOn: Binding(
                    get: { columnManager.isVisible(column) },
                    set: { _ in
                        if !column.isRequired {
                            columnManager.toggleVisibility(column)
                        }
                    }
                ))
                .disabled(column.isRequired)
            }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
