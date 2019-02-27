#import <Foundation/Foundation.h>

typedef struct {
	float x;
	float y;
} mtPoint;

typedef struct {
	mtPoint position;
	mtPoint velocity;
} mtVector;

typedef struct {
  int frame; // the current frame
  double timestamp; // event timestamp
	int identifier; // identifier guaranteed unique for life of touch per device
	int state; //the current state (not sure what the values mean)
	int unknown1; //no idea what this does
	int unknown2; //no idea what this does either
	mtVector normalized; //the normalized position and vector of the touch (0,0 to 1,1)
	float size; //the size of the touch (the area of your finger being tracked)
	int unknown3; //no idea what this does
	float angle; //the angle of the touch            -|
	float majorAxis; //the major axis of the touch   -|-- an ellipsoid. you can track the angle of each finger!
	float minorAxis; //the minor axis of the touch   -|
	mtVector unknown4; //not sure what this is for
	int unknown5[2]; //no clue
	float unknown6; //no clue
} mtTouch;

typedef void *MTDeviceRef; //a reference pointer for the multitouch device
typedef int (*MTContactCallbackFunction)(MTDeviceRef,mtTouch*,int,double,int); //the prototype for the callback function

MTDeviceRef MTDeviceCreateDefault(); //returns a pointer to the default device (the trackpad)
CFMutableArrayRef MTDeviceCreateList(void); //returns a CFMutableArrayRef array of all multitouch devices
void* MTRegisterContactFrameCallback(MTDeviceRef, MTContactCallbackFunction); //registers a device's frame callback to your callback function
void MTDeviceStart(MTDeviceRef, int); //start sending events

void MTUnregisterContactFrameCallback(MTDeviceRef, MTContactCallbackFunction);
void MTDeviceStop(MTDeviceRef);

MTDeviceRef MTDeviceCreateFromService(io_service_t);
io_service_t MTDeviceGetService(MTDeviceRef);

void MTDeviceGetSensorSurfaceDimensions(MTDeviceRef, int*, int *); // in 100ths of mm

bool MTDeviceIsBuiltIn(MTDeviceRef);

/*
 micro-Meh:MultitouchSupport.framework rpointon$ nm MultitouchSupport | grep MTDevice
 000000000000f9cc T _MTDeviceBeginRecordingToData
 000000000000f438 T _MTDeviceBeginRecordingToFile
 0000000000004099 T _MTDeviceCreate
 0000000000001bf3 T _MTDeviceCreateDefault
 000000000000201f T _MTDeviceCreateFromDeviceID
 0000000000001e2f T _MTDeviceCreateFromGUID
 0000000000001720 T _MTDeviceCreateFromService
 00000000000014c0 T _MTDeviceCreateList
 00000000000027c2 T _MTDeviceCreateMultitouchRunLoopSource
 0000000000004fc6 T _MTDeviceDispatchButtonEvent
 0000000000005005 T _MTDeviceDispatchKeyboardEvent
 0000000000004ffb T _MTDeviceDispatchMomentumScrollEvent
 0000000000004fe2 T _MTDeviceDispatchMomentumScrollStartStopEvent
 0000000000004fbc T _MTDeviceDispatchRelativeMouseEvent
 0000000000004fd8 T _MTDeviceDispatchScrollWheelEvent
 00000000000035ff T _MTDeviceDriverIsReady
 000000000000fb5a T _MTDeviceEndRecording
 0000000000002230 T _MTDeviceForcePropertiesRecache
 000000000000389f T _MTDeviceForcePropertiesRecacheForAll
 0000000000004618 T _MTDeviceGetCriticalErrors
 0000000000001b81 T _MTDeviceGetDeviceID
 00000000000035c5 T _MTDeviceGetDriverType
 0000000000001b4a T _MTDeviceGetFamilyID
 0000000000001a5c T _MTDeviceGetGUID
 0000000000003f48 T _MTDeviceGetParserEnabled
 0000000000003812 T _MTDeviceGetParserOptions
 00000000000037e7 T _MTDeviceGetParserType
 0000000000002ca9 T _MTDeviceGetPeripheralRunLoopSource
 0000000000004592 T _MTDeviceGetReport
 00000000000034e1 T _MTDeviceGetSensorDimensions
 0000000000003673 T _MTDeviceGetSensorRegionOfType
 0000000000003537 T _MTDeviceGetSensorSurfaceDimensions
 000000000000358d T _MTDeviceGetSerialNumber
 0000000000003663 T _MTDeviceGetService
 00000000000036e8 T _MTDeviceGetThresholdsForSensorRegionOfType
 0000000000001bb9 T _MTDeviceGetTransportMethod
 0000000000004054 T _MTDeviceGetTypeID
 00000000000034aa T _MTDeviceGetVersion
 0000000000003b7a T _MTDeviceIsAlive
 000000000000205f T _MTDeviceIsAvailable
 000000000000386e T _MTDeviceIsBuiltIn
 000000000000383d T _MTDeviceIsMTHIDDevice
 0000000000003491 T _MTDeviceIsOpaqueSurface
 000000000000221a T _MTDeviceIsRunning
 000000000000390d T _MTDeviceIssueDriverRequest
 000000000000fcb4 T _MTDeviceMarkRecording
 0000000000003be0 T _MTDevicePowerControlSupported
 0000000000003ca1 T _MTDevicePowerGetEnabled
 0000000000003c41 T _MTDevicePowerSetEnabled
 000000000000204e T _MTDeviceRelease
 0000000000003010 T _MTDeviceScheduleOnRunLoop
 000000000000ba92 T _MTDeviceSetFaceDetectionModeEnabled
 000000000000b83c T _MTDeviceSetInputDetectionCallbackTriggerMask
 000000000000baae T _MTDeviceSetInputDetectionMode
 000000000000baba T _MTDeviceSetInputDetectionModeForOrientation
 000000000000fe0c T _MTDeviceSetMaxRecordingLength
 0000000000003ece T _MTDeviceSetParserEnabled
 0000000000005030 T _MTDeviceSetPickButtonShouldSendSecondaryClick
 00000000000045bf T _MTDeviceSetReport
 000000000000bda9 T _MTDeviceSetSurfaceOrientation
 000000000000be18 T _MTDeviceSetSurfaceOrientationMode
 0000000000003d5d T _MTDeviceSetUILocked
 00000000000045f9 T _MTDeviceSetZephyrParameter
 0000000000002087 T _MTDeviceStart
 0000000000002aa2 T _MTDeviceStop
 0000000000003e6d T _MTDeviceUpdatePowerStatistics
*/