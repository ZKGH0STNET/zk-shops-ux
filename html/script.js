// NUI Message handler for FiveM
let currentShop = null;

// Function to populate the inventory grid with shop items
function populateInventory(shop, items) {
    if (!shop || !items) {
        console.error('Invalid shop data received');
        return;
    }
    
    // Store the current shop name for purchase calls
    currentShop = shop.name;
    
    // Set the shop title
    document.querySelector('.title').textContent = shop.name;
    
    // Clear existing items
    const grid = document.getElementById('inventory-grid');
    grid.innerHTML = '';
    
    // Create slots for each item
    items.forEach(item => {
        const slot = document.createElement('div');
        slot.className = 'item';
        
        // Create image element
        const img = document.createElement('img');
        img.src = `nui://ox_inventory/web/images/${item.name}.png`;
        img.alt = item.label || item.name;
        img.onerror = () => img.src = 'https://i.imgur.com/uYMkWxZ.png';
        slot.appendChild(img);
        
        // Create name element
        const name = document.createElement('div');
        name.className = 'name';
        name.textContent = item.label || item.name;
        slot.appendChild(name);
        
        // Create price element (left bottom)
        const price = document.createElement('div');
        price.className = 'price';
        price.textContent = '$' + item.price;
        slot.appendChild(price);
        
        // Create quantity element (right bottom)
        const quantity = document.createElement('div');
        quantity.className = 'quantity';
        quantity.textContent = item.amount > 1 ? 'x' + item.amount : '';
        slot.appendChild(quantity);
        
        grid.appendChild(slot);
        
        // When an item is clicked, purchase it
        slot.onclick = () => {
            $.post('https://zk-custom-shops/purchaseItem', JSON.stringify({
                shop: currentShop,
                item: item.name,
                quantity: 1,
                price: item.price
            }));
        };
    });
}

// Listen for messages from the client script
window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.action === 'open') {
        document.getElementById('inventory-wrapper').style.display = 'flex';
        document.getElementById('inventory-wrapper').classList.remove('hidden');
        populateInventory(data.shop, data.items);
    } else if (data.action === 'close') {
        document.getElementById('inventory-wrapper').style.display = 'none';
    } else if (data.action === 'update') {
        populateInventory(data.shop, data.items);
    }
});

// Close on ESC key
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        document.getElementById('inventory-wrapper').style.display = 'none';
        $.post('https://zk-custom-shops/closeShop', JSON.stringify({}));
    }
});
