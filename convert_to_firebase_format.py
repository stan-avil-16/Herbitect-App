import json

# Read the current JSON file
with open('assets/plants.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# Convert plants array to map
plants_array = data['plants']
plants_map = {}

for i, plant in enumerate(plants_array):
    plants_map[str(i)] = plant

# Create new structure
firebase_data = {
    "plants": plants_map,
    "users": data['users']
}

# Write the converted data
with open('assets/plants_firebase.json', 'w', encoding='utf-8') as f:
    json.dump(firebase_data, f, indent=2, ensure_ascii=False)

print(f"Converted {len(plants_array)} plants to Firebase format")
print("Output saved to assets/plants_firebase.json")
print("\nFirst few plants:")
for i in range(min(3, len(plants_array))):
    print(f"  {i}: {plants_array[i]['name']}") 