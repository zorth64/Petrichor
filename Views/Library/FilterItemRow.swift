import SwiftUI

struct FilterItemRow: View {
    let item: LibraryFilterItem
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Text(item.name)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .lineLimit(1)
                .foregroundColor(isSelected ? .white : .primary)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            onTap()
        }
        .padding(.horizontal, 8)
    }
}

#Preview {
    VStack {
        FilterItemRow(
            item: LibraryFilterItem(name: "The Beatles", count: 23, filterType: .artists),
            isSelected: false,
            onTap: { print("Tapped") }
        )
        
        FilterItemRow(
            item: LibraryFilterItem(name: "Pink Floyd", count: 15, filterType: .artists),
            isSelected: true,
            onTap: { print("Tapped") }
        )
        
        FilterItemRow(
            item: LibraryFilterItem.allItem(for: .artists, totalCount: 156),
            isSelected: false,
            onTap: { print("Tapped") }
        )
    }
    .padding()
}
