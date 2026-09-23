declare module "@salesforce/apex/SeatBookingController.getFloors" {
  export default function getFloors(): Promise<any>;
}
declare module "@salesforce/apex/SeatBookingController.getFloorWiseStatus" {
  export default function getFloorWiseStatus(): Promise<any>;
}
declare module "@salesforce/apex/SeatBookingController.getSeats" {
  export default function getSeats(param: {floorId: any}): Promise<any>;
}
declare module "@salesforce/apex/SeatBookingController.getFloorSeatCount" {
  export default function getFloorSeatCount(param: {floorId: any}): Promise<any>;
}
declare module "@salesforce/apex/SeatBookingController.isSeatAvailable" {
  export default function isSeatAvailable(param: {seatId: any}): Promise<any>;
}
declare module "@salesforce/apex/SeatBookingController.bookSeat" {
  export default function bookSeat(param: {seatId: any, customerName: any, email: any, aadhaar: any}): Promise<any>;
}
declare module "@salesforce/apex/SeatBookingController.getBookingDetails" {
  export default function getBookingDetails(param: {seatId: any}): Promise<any>;
}
declare module "@salesforce/apex/SeatBookingController.cancelBooking" {
  export default function cancelBooking(param: {seatId: any}): Promise<any>;
}
