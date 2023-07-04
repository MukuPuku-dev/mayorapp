import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';



class Order {
  String? id;
  DateTime dateTime;
  String order;
  bool isFollowed;

  Order(this.dateTime, this.order, {this.isFollowed = false, this.id});
}


class Decisions extends StatefulWidget {
  @override
  _DecisionsState createState() => _DecisionsState();
}

class _DecisionsState extends State<Decisions> {
  FirestoreService firestoreService = FirestoreService();
  List<Order> orders = [];
  List<Order> originalOrders = [];
  String selectedFilter = ''; // Variable to track the selected filter

  @override
  void initState() {
    super.initState();
    _loadOriginalOrders();
  }

  Future<void> _loadOriginalOrders() async {
    List<Order> loadedOrders = await firestoreService.getOriginalOrders();
    setState(() {
      orders = loadedOrders;
      originalOrders = loadedOrders;
    });
  }

  void addOrder({Order? orderToEdit}) async {
    DateTime selectedDateTime = orderToEdit?.dateTime ?? DateTime.now();
    String orderText = orderToEdit?.order ?? '';

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.add, color: Colors.green),
                  SizedBox(width: 8),
                  Text(orderToEdit != null ? 'Edit Order' : 'Add Order'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Date:', style: TextStyle(fontWeight: FontWeight.bold)),

                        TextButton(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDateTime,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() {
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
                          child: Text(
                            DateFormat('MMM d, yyyy').format(selectedDateTime),
                            style: TextStyle(fontSize: 16),
                          ),
                        ),

                        Text('Time:', style: TextStyle(fontWeight: FontWeight.bold)),

                        TextButton(
                          onPressed: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                            );
                            if (picked != null) {
                              setState(() {
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
                          child: Text(
                            DateFormat.jm().format(selectedDateTime),
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text('Order:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: TextField(
                        controller: TextEditingController(text: orderText),
                        onChanged: (value) {
                          orderText = value;
                        },
                        maxLines: 4,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.all(8),
                          border: InputBorder.none,
                          hintText: 'Enter your order...',
                        ),
                      ),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false); // Return false as a result
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
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
                      orders.add(newOrder);
                      originalOrders.add(newOrder);
                      await firestoreService.addOrder(newOrder);
                      print('New order added');
                    }
                    Navigator.of(context).pop(true); // Return true as a result
                  },
                  child: Text(orderToEdit != null ? 'Update' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );

    // Update the UI only if the order was added or updated
    if (result == true) {
      setState(() {
        // Perform any other UI updates here if needed
      });
    }
  }


  Future<void> deleteOrder(Order order) async {
    await firestoreService.deleteOrder(order);
    setState(() {
      orders.remove(order);
      originalOrders.remove(order);
    });
  }

  int getTotalOrdersCount() {
    return originalOrders.length;
  }

  void toggleFollowed(Order order) {
    setState(() {
      order.isFollowed = !order.isFollowed;
      firestoreService.updateOrder(order);
    });
  }

  List<Order> getFilteredOrders(bool onlyFollowed) {
    return originalOrders.where((order) => onlyFollowed ? order.isFollowed : !order.isFollowed).toList();
  }

  @override
  Widget build(BuildContext context) {
    int totalOrders = getTotalOrdersCount();
      int totalFollowed = orders.where((order) => order.isFollowed).length;
    int totalUnfollowed = orders.length - totalFollowed;

    return Scaffold(
      appBar: AppBar(
        title: Text('Decisions'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Orders',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$totalOrders',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      'Followed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Unfollowed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      '$totalFollowed',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '$totalUnfollowed',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: addOrder,
                icon: Icon(Icons.add),
                label: Text('Add Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  textStyle: TextStyle(fontSize: 18),
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    orders.sort((a, b) => a.dateTime.compareTo(b.dateTime));
                  });
                },
                icon: Icon(Icons.sort),
                label: Text('Sort by Date'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  textStyle: TextStyle(fontSize: 18),
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                Order order = orders[index];

                return Dismissible(
                  key: Key(order.dateTime.toString()),
                  direction: DismissDirection.horizontal,
                  onDismissed: (direction) {
                    deleteOrder(order);
                  },
                  child: Card(
                    elevation: 2,
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(
                        order.order,
                        style: TextStyle(fontSize: 16),
                      ),
                      subtitle: Text(
                        order.dateTime.toString(),
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: order.isFollowed,
                            onChanged: (value) => toggleFollowed(order),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit),
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
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedFilter = 'followed';
                    orders = getFilteredOrders(true);
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedFilter == 'followed' ? Colors.green : null, // Apply a different color when the filter is selected
                ),
                child: Text('Followed Orders'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedFilter = 'unfollowed';
                    orders = getFilteredOrders(false);
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedFilter == 'unfollowed' ? Colors.green : null, // Apply a different color when the filter is selected
                ),
                child: Text('Unfollowed Orders'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedFilter = 'all';
                    orders = List.from(originalOrders);
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedFilter == 'all' ? Colors.green : null, // Apply a different color when the filter is selected
                ),
                child: Text('All Orders'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FirestoreService {
  final CollectionReference ordersCollection =
  FirebaseFirestore.instance.collection('orders');

  Future<List<Order>> getOriginalOrders() async {
    QuerySnapshot querySnapshot = await ordersCollection.get();
    List<Order> originalOrders = [];
    for (QueryDocumentSnapshot documentSnapshot in querySnapshot.docs) {
      Map<String, dynamic> data = documentSnapshot.data() as Map<String, dynamic>;
      String orderId = documentSnapshot.id; // Retrieve the document ID
      print("ORder IS $orderId");
      DateTime dateTime = data['dateTime'].toDate();
      String orderText = data['order'];
      bool isFollowed = data['isFollowed'];
      Order order = Order(dateTime, orderText, isFollowed: isFollowed,id:orderId);
      originalOrders.add(order);
    }

    return originalOrders;
  }

  Future<void> addOrder(Order order) async {
    await ordersCollection.add({
      'dateTime': order.dateTime,
      'order': order.order,
      'isFollowed': order.isFollowed,
    });
  }

  Future<void> updateOrder(Order order) async {
    print("orderid ${order.id}");
    try {
      DocumentReference documentRef =
      ordersCollection.doc(order.id);

      DocumentSnapshot documentSnapshot = await documentRef.get();
      if (documentSnapshot.exists) {
        await documentRef.update({
          'dateTime': order.dateTime,
          'order': order.order,
          'isFollowed': order.isFollowed,
        });
        print('Order updated');
      } else {
        print('Order not found');
      }
    } catch (error) {
      print('Error updating order: $error');
    }
  }


  Future<void> deleteOrder(Order order) async {
    await ordersCollection.doc(order.id).delete();
  }
}


void main() {
  runApp(MaterialApp(
    title: 'Decisions App',
    home: Decisions(),
  ));
}
