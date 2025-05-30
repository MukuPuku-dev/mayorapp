import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single decision or order.
class Order {
  String? id; // Firestore document ID
  DateTime dateTime; // Date and time of the order
  String order; // Text content of the order
  bool isFollowed; // Status indicating if the order is being followed up

  /// Constructs an [Order].
  ///
  /// [dateTime] and [order] are required.
  /// [isFollowed] defaults to false.
  /// [id] is optional and typically assigned by Firestore.
  Order(this.dateTime, this.order, {this.isFollowed = false, this.id});
}

/// A StatefulWidget that displays and manages a list of decisions/orders.
class Decisions extends StatefulWidget {
  @override
  _DecisionsState createState() => _DecisionsState();
}

/// State class for the [Decisions] widget.
class _DecisionsState extends State<Decisions> {
  // Service to interact with Firestore for order data.
  FirestoreService firestoreService = FirestoreService();
  // List of orders currently displayed in the UI (can be filtered).
  List<Order> orders = [];
  // Original list of all orders fetched from Firestore, used as a base for filtering.
  List<Order> originalOrders = [];
  // Tracks the currently active filter ('followed', 'unfollowed', or 'all').
  String selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    // Load initial orders when the widget is first created.
    _loadOriginalOrders();
  }

  /// Loads all orders from Firestore and updates the state.
  Future<void> _loadOriginalOrders() async {
    List<Order> loadedOrders = await firestoreService.getOriginalOrders();
    if (mounted) { // Ensure the widget is still in the tree before calling setState.
      setState(() {
        orders = loadedOrders; // Initially, displayed orders are all original orders.
        originalOrders = loadedOrders;
      });
    }
  }

  /// Opens a dialog to add a new order or edit an existing [orderToEdit].
  void addOrder({Order? orderToEdit}) async {
    DateTime selectedDateTime = orderToEdit?.dateTime ?? DateTime.now();
    String orderText = orderToEdit?.order ?? '';

    // Show a dialog and wait for its result (true if an order was added/updated, false otherwise).
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        // Use StatefulBuilder to manage the state within the dialog (e.g., for date/time pickers).
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) { // Renamed setState to avoid conflict
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.add_circle_outline, color: Colors.green), // More descriptive icon
                  SizedBox(width: 8),
                  Text(orderToEdit != null ? 'Edit Order' : 'Add New Order'), // Slightly more descriptive
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date and Time selection row
                    Wrap( // Use Wrap for better responsiveness if space is limited
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: [
                        TextButton.icon(
                          icon: Icon(Icons.calendar_today),
                          label: Text(DateFormat('MMM d, yyyy').format(selectedDateTime)),
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDateTime,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setStateDialog(() { // Use dialog's own setState
                                selectedDateTime = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  selectedDateTime.hour,
                                  selectedDateTime.minute,
                                );
                              });
                            }
                          },
                        ),
                        TextButton.icon(
                          icon: Icon(Icons.access_time),
                          label: Text(DateFormat.jm().format(selectedDateTime)),
                          onPressed: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                            );
                            if (picked != null) {
                              setStateDialog(() { // Use dialog's own setState
                                selectedDateTime = DateTime(
                                  selectedDateTime.year,
                                  selectedDateTime.month,
                                  selectedDateTime.day,
                                  picked.hour,
                                  picked.minute,
                                );
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text('Order Details:', style: TextStyle(fontWeight: FontWeight.bold)), // Clearer label
                    SizedBox(height: 8),
                    // Text field for the order description.
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400), // Slightly softer border
                        borderRadius: BorderRadius.circular(8), // More rounded corners
                      ),
                      child: TextField(
                        controller: TextEditingController(text: orderText),
                        onChanged: (value) {
                          orderText = value;
                        },
                        maxLines: 4,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.all(12), // Increased padding
                          border: InputBorder.none,
                          hintText: 'Enter order details here...',
                        ),
                      ),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false); // Indicate no change made.
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () async {
                    if (orderToEdit != null) {
                      // Update existing order
                      orderToEdit.dateTime = selectedDateTime;
                      orderToEdit.order = orderText;
                      await firestoreService.updateOrder(orderToEdit);
                      print('Order updated');
                    } else {
                      // Add new order
                      Order newOrder = Order(selectedDateTime, orderText);
                      await firestoreService.addOrder(newOrder);
                      print('New order added');
                    }
                    Navigator.of(context).pop(true); // Indicate change was made.
                  },
                  child: Text(orderToEdit != null ? 'Update' : 'Add', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      _loadOriginalOrders(); 
    }
  }

  Future<void> deleteOrder(Order order) async {
    await firestoreService.deleteOrder(order);
    _loadOriginalOrders();
  }

  int getTotalOrdersCount() {
    return originalOrders.length;
  }

  void toggleFollowed(Order order) {
    if (mounted) {
      setState(() {
        order.isFollowed = !order.isFollowed;
        firestoreService.updateOrder(order);
      });
    }
  }

  List<Order> getFilteredOrders(bool onlyFollowed) {
    return originalOrders
        .where((order) => onlyFollowed ? order.isFollowed : !order.isFollowed)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    int totalOrders = originalOrders.length;
    int totalFollowed = originalOrders.where((order) => order.isFollowed).length;
    int totalUnfollowed = totalOrders - totalFollowed;

    // Consistent button styling
    final ButtonStyle- buttonStyle = ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600));

    final ButtonStyle- selectedButtonStyle = buttonStyle.copyWith(
      backgroundColor: MaterialStateProperty.all(Colors.green[700]), // Darker green when selected
      foregroundColor: MaterialStateProperty.all(Colors.white),
    );
    final ButtonStyle- unselectedButtonStyle = buttonStyle.copyWith(
      backgroundColor: MaterialStateProperty.all(Colors.grey[300]),
    );


    return Scaffold(
      appBar: AppBar(
        title: Text('Decisions Dashboard'), // More descriptive title
        backgroundColor: Colors.blue[700], // Darker blue for AppBar
        elevation: 4, // Add some elevation
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(20), // Increased padding
            decoration: BoxDecoration(
              color: Colors.blue[600], // Slightly adjusted color
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))
              ],
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center, // Center align text
              children: [
                Text(
                  'Total Orders',
                  style: TextStyle(
                    fontSize: 22, // Slightly larger
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$totalOrders',
                  style: TextStyle(
                    fontSize: 40, // Larger count
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 20), // Increased spacing
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround, // Adjusted spacing
                  children: [
                    _buildStatColumn('Followed', '$totalFollowed'),
                    _buildStatColumn('Unfollowed', '$totalUnfollowed'),
                  ],
                ),
              ],
            ),
          ),
          Padding( // Added padding for buttons
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: addOrder,
                  icon: Icon(Icons.add_circle_outline), // More descriptive icon
                  label: Text('Add Order'),
                  style: buttonStyle.copyWith(backgroundColor: MaterialStateProperty.all(Colors.green[600])),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        orders.sort((a, b) => a.dateTime.compareTo(b.dateTime));
                      });
                    }
                  },
                  icon: Icon(Icons.sort_by_alpha), // Changed icon
                  label: Text('Sort by Date'),
                   style: buttonStyle.copyWith(backgroundColor: MaterialStateProperty.all(Colors.orange[700])),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(bottom: 8.0), // Add padding at the bottom of list
              itemCount: orders.length,
              itemBuilder: (context, index) {
                Order order = orders[index];
                return Dismissible(
                  key: Key(order.id ?? order.dateTime.toIso8601String()),
                  direction: DismissDirection.endToStart, // Only allow swipe from right to left
                  onDismissed: (direction) {
                    deleteOrder(order);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("${order.order} deleted"), duration: Duration(seconds: 2))
                    );
                  },
                  background: Container(
                    color: Colors.red[700],
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Icon(Icons.delete_sweep, color: Colors.white), // More descriptive icon
                  ),
                  child: Card(
                    elevation: 3, // Slightly more elevation
                    margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Adjusted margin
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Rounded corners
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Adjusted padding
                      title: Text(
                        order.order,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500), // Slightly bolder title
                      ),
                      subtitle: Text(
                        DateFormat('MMM d, yyyy - hh:mm a').format(order.dateTime),
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]), // Slightly larger subtitle
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: order.isFollowed,
                            onChanged: (value) => toggleFollowed(order),
                            activeColor: Theme.of(context).primaryColor,
                          ),
                          IconButton(
                            icon: Icon(Icons.edit_note, color: Colors.blueGrey), // More descriptive icon
                            tooltip: "Edit Order",
                            onPressed: () {
                              addOrder(orderToEdit: order);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding( // Added padding for filter buttons
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        selectedFilter = 'followed';
                        orders = getFilteredOrders(true);
                      });
                    }
                  },
                  style: selectedFilter == 'followed' ? selectedButtonStyle : unselectedButtonStyle,
                  child: Text('Followed'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        selectedFilter = 'unfollowed';
                        orders = getFilteredOrders(false);
                      });
                    }
                  },
                  style: selectedFilter == 'unfollowed' ? selectedButtonStyle : unselectedButtonStyle,
                  child: Text('Unfollowed'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        selectedFilter = 'all';
                        orders = List.from(originalOrders);
                      });
                    }
                  },
                   style: selectedFilter == 'all' ? selectedButtonStyle : unselectedButtonStyle,
                  child: Text('All Orders'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Helper widget to build a column for displaying statistics (e.g., Followed, Unfollowed counts).
  Widget _buildStatColumn(String title, String count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16, // Adjusted size
            fontWeight: FontWeight.bold,
            color: Colors.white.withOpacity(0.9), // Slightly transparent for subtlety
          ),
        ),
        SizedBox(height: 4), // Reduced space
        Text(
          count,
          style: TextStyle(
            fontSize: 26, // Adjusted size
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}


/// Service class for handling Firestore operations related to 'orders'.
class FirestoreService {
  // Reference to the 'orders' collection in Firestore.
  final CollectionReference ordersCollection =
      FirebaseFirestore.instance.collection('orders');

  /// Fetches all orders from the Firestore 'orders' collection, ordered by dateTime descending.
  ///
  /// Returns a list of [Order] objects.
  Future<List<Order>> getOriginalOrders() async {
    QuerySnapshot querySnapshot =
        await ordersCollection.orderBy('dateTime', descending: true).get();
    List<Order> originalOrders = [];
    for (QueryDocumentSnapshot documentSnapshot in querySnapshot.docs) {
      Map<String, dynamic> data =
          documentSnapshot.data() as Map<String, dynamic>;
      String orderId = documentSnapshot.id; 
      DateTime dateTime = data['dateTime'].toDate();
      String orderText = data['order'];
      bool isFollowed = data['isFollowed'] ?? false; 
      Order order =
          Order(dateTime, orderText, isFollowed: isFollowed, id: orderId);
      originalOrders.add(order);
    }
    return originalOrders;
  }

  /// Adds a new [order] to the Firestore 'orders' collection.
  Future<void> addOrder(Order order) async {
    try {
      await ordersCollection.add({
        'dateTime': order.dateTime,
        'order': order.order,
        'isFollowed': order.isFollowed,
      });
    } catch (e) {
      print("Error adding order: $e");
      // Consider rethrowing or returning a status to inform the UI
    }
  }

  /// Updates an existing [order] in the Firestore 'orders' collection.
  ///
  /// Uses the [order.id] to identify the document to update.
  Future<void> updateOrder(Order order) async {
    if (order.id == null) {
      print("Order ID is null, cannot update.");
      return;
    }
    try {
      DocumentReference documentRef = ordersCollection.doc(order.id);
      DocumentSnapshot documentSnapshot = await documentRef.get();

      if (documentSnapshot.exists) {
        await documentRef.update({
          'dateTime': order.dateTime,
          'order': order.order,
          'isFollowed': order.isFollowed,
        });
      } else {
        print('Order not found in Firestore, cannot update.');
      }
    } catch (error) {
      print('Error updating order in Firestore: $error');
      // Consider rethrowing or returning a status
    }
  }

  /// Deletes an [order] from the Firestore 'orders' collection.
  ///
  /// Uses the [order.id] to identify the document to delete.
  Future<void> deleteOrder(Order order) async {
    if (order.id == null) {
      print("Order ID is null, cannot delete.");
      return;
    }
    try {
      await ordersCollection.doc(order.id).delete();
    } catch (e) {
      print("Error deleting order: $e");
      // Consider rethrowing or returning a status
    }
  }
}
