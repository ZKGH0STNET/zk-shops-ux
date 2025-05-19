// Script for ZK-Shop-UX interface
let currentShop = '';
let shopItems = [];
let selectedItem = null;

// Utility functions
function formatCurrency(amount) {
    return '$' + parseInt(amount).toLocaleString();
}

// Initialize the interface
function initializeInterface() {
    // Set up event listeners
    document.getElementById('close-shop').addEventListener('click', closeShop);
    document.getElementById('close-dialog').addEventListener('click', closePurchaseDialog);
    document.getElementById('cancel-purchase').addEventListener('click', closePurchaseDialog);
    document.getElementById('confirm-purchase').addEventListener('click', confirmPurchase);
    document.getElementById('increase-quantity').addEventListener('click', increaseQuantity);
    document.getElementById('decrease-quantity').addEventListener('click', decreaseQuantity);
    
    // Handle quantity input changes
    const quantityInput = document.getElementById('purchase-quantity');
    quantityInput.addEventListener('change', updateTotalPrice);
    quantityInput.addEventListener('input', updateTotalPrice);
    
    // Listen for keyboard events
    document.addEventListener('keydown', function(event) {
        if (event.key === 'Escape') {
            if (document.getElementById('purchase-dialog').classList.contains('hidden')) {
                closeShop();
            } else {
                closePurchaseDialog();
            }
        }
    });
}

// Load shop items
function loadShopItems(items) {
    shopItems = items;
    const grid = document.getElementById('items-grid');
    grid.innerHTML = ''; // Clear existing items
    
    if (!items || items.length === 0) {
        const emptyMessage = document.createElement('div');
        emptyMessage.className = 'empty-shop';
        emptyMessage.textContent = 'Esta tienda no tiene productos disponibles';
        grid.appendChild(emptyMessage);
        return;
    }
    
    // Create an item element for each shop item
    items.forEach(item => {
        if (item.amount <= 0) return; // Skip items with no stock
        
        const itemElement = document.createElement('div');
        itemElement.className = 'item';
        itemElement.dataset.name = item.name;
        
        // Create image element
        const img = document.createElement('img');
        img.src = `https://cfx-nui-ox_inventory/web/images/${item.name}.png`;
        img.alt = item.label || item.name;
        img.onerror = function() {
            this.src = 'https://i.imgur.com/uYMkWxZ.png'; // Fallback image
        };
        itemElement.appendChild(img);
        
        // Create name element
        const name = document.createElement('div');
        name.className = 'item-name';
        name.textContent = item.label || item.name;
        itemElement.appendChild(name);
        
        // Create price element
        const price = document.createElement('div');
        price.className = 'item-price';
        price.textContent = formatCurrency(item.price);
        itemElement.appendChild(price);
        
        // Create amount element
        const amount = document.createElement('div');
        amount.className = 'item-amount';
        amount.textContent = 'x' + item.amount;
        itemElement.appendChild(amount);
        
        // Add click event
        itemElement.addEventListener('click', () => openPurchaseDialog(item));
        
        grid.appendChild(itemElement);
    });
}

// Open purchase dialog
function openPurchaseDialog(item) {
    selectedItem = item;
    
    // Set dialog values
    document.getElementById('purchase-item-name').textContent = item.label || item.name;
    document.getElementById('purchase-item-image').src = `https://cfx-nui-ox_inventory/web/images/${item.name}.png`;
    document.getElementById('purchase-item-image').onerror = function() {
        this.src = 'https://i.imgur.com/uYMkWxZ.png';
    };
    document.getElementById('purchase-item-price').textContent = formatCurrency(item.price);
    document.getElementById('purchase-item-available').textContent = item.amount;
    
    // Reset quantity
    document.getElementById('purchase-quantity').value = 1;
    document.getElementById('purchase-quantity').max = item.amount;
    
    // Update total price
    updateTotalPrice();
    
    // Show dialog
    document.getElementById('purchase-dialog').classList.remove('hidden');
}

// Close purchase dialog
function closePurchaseDialog() {
    document.getElementById('purchase-dialog').classList.add('hidden');
    selectedItem = null;
}

// Update total price
function updateTotalPrice() {
    if (!selectedItem) return;
    
    const quantity = parseInt(document.getElementById('purchase-quantity').value) || 1;
    const totalPrice = quantity * selectedItem.price;
    
    document.getElementById('purchase-total-price').textContent = formatCurrency(totalPrice);
}

// Increase quantity
function increaseQuantity() {
    const quantityInput = document.getElementById('purchase-quantity');
    const currentValue = parseInt(quantityInput.value) || 1;
    const maxValue = parseInt(quantityInput.max) || 99;
    
    if (currentValue < maxValue) {
        quantityInput.value = currentValue + 1;
        updateTotalPrice();
    }
}

// Decrease quantity
function decreaseQuantity() {
    const quantityInput = document.getElementById('purchase-quantity');
    const currentValue = parseInt(quantityInput.value) || 1;
    
    if (currentValue > 1) {
        quantityInput.value = currentValue - 1;
        updateTotalPrice();
    }
}

// Confirm purchase
function confirmPurchase() {
    if (!selectedItem) return;
    
    const quantity = parseInt(document.getElementById('purchase-quantity').value) || 1;
    const totalPrice = quantity * selectedItem.price;
    
    // Send purchase data to client script
    $.post('https://zk-shop-ux/purchaseItem', JSON.stringify({
        item: selectedItem.name,
        quantity: quantity,
        price: selectedItem.price
    }));
    
    // Close dialogs
    closePurchaseDialog();
}

// Close shop
function closeShop() {
    $.post('https://zk-shop-ux/closeShop', JSON.stringify({}));
}

// Listen for messages from client script
window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.action === 'open') {
        currentShop = data.shopName || 'Tienda';
        document.getElementById('shop-name').textContent = currentShop;
        loadShopItems(data.items || []);
        if (data.money !== undefined) {
            document.getElementById('player-money').textContent = formatCurrency(data.money);
        }
        document.getElementById('main-container').style.display = 'flex';
        console.log('ZK-SHOPS: Shop opened - ' + currentShop);
    } 
    else if (data.action === 'close') {
        document.getElementById('main-container').style.display = 'none';
        closePurchaseDialog();
        console.log('ZK-SHOPS: Shop closed');
    } 
    else if (data.action === 'update') {
        if (data.shopName === currentShop) {
            loadShopItems(data.items || []);
            console.log('ZK-SHOPS: Shop items updated');
        }
    }
    else if (data.action === 'setMoney' || data.action === 'updateMoney') {
        // Actualizamos la visualización del dinero del jugador
        if (data.money !== undefined) {
            document.getElementById('player-money').textContent = formatCurrency(data.money);
            console.log('ZK-SHOPS: Money updated to ' + data.money);
        }
    }
    else if (data.action === 'refresh') {
        // Actualizamos todos los datos sin reabrir la tienda
        if (data.shopName) {
            currentShop = data.shopName;
            document.getElementById('shop-name').textContent = currentShop;
        }
        if (data.items) {
            loadShopItems(data.items);
        }
        if (data.money !== undefined) {
            document.getElementById('player-money').textContent = formatCurrency(data.money);
        }
        console.log('ZK-SHOPS: Shop data refreshed');
    }
});

// Initialize the interface when DOM is loaded
document.addEventListener('DOMContentLoaded', initializeInterface);

// Hide the interface by default
document.getElementById('main-container').style.display = 'none';
