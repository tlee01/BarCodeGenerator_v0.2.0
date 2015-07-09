<!---
2DBarCode_j4l.cfc - wrapper class for using some of the Java4Less barcode libraries.
To use this you'll need to purchase the related java libraries from Java4less - http://www.java4less.com.
They do have a free evaluation version for download that will work fine for testing.
I have no affiliation with them other than I needed to use their product in ColdFusion.
Note that this class only deals with 2D/Data Matrix barcodes.  Java4Less offers 
libraries for reading/writing regular barcodes, but I have not used them. Works on
any image type that the ColdFusion cfimage tag can read. Requires ColdFusion 8.
See included readme.htm file for more details.

Written by Ryan Stille, CF WebTools.   
My blog: http://www.stillnetstudios.com   
My company: http://www.cfwebtools.com   
Send feedback to ryan@cfwebtools.com.    
Copyright 2007 Ryan Stille / CFWebTools   
 
Licensed under the Apache License, Version 2.0 (the "License");   
you may not use this file except in compliance with the License.   
You may obtain a copy of the License at   

    http://www.apache.org/licenses/LICENSE-2.0   

Unless required by applicable law or agreed to in writing, software   
distributed under the License is distributed on an "AS IS" BASIS,   
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   
See the License for the specific language governing permissions and   
limitations under the License.  

 --->

<cfcomponent displayname="Wrapper for Java4Less 2D BarCode libraries">

	<cffunction name="init">
		
		<!--- used below, see comment there. --->
		<cfset var sys = ''>
		<!--- create a temporary instance of the writer, just to make sure it is available. 
		We can't create a persistance instance of this because it is not thread safe. --->
		<cfset var Writer = CreateObject('java',"com.java4less.rdatamatrix.RDataMatrix").init()>
		
		<!--- create a persistant instance of the reader that will be used by the reading functions --->
		<cfset variables.Reader = CreateObject('java',"com.java4less.vision.datamatrix.DatamatrixReader").init()>
		
		<!--- The DatamatrixReader class looks for the com.java4less.vision.maxarea property
		to see how much area of an image it should scan through to find a barcode. By default this
		is 9000, which is way too small (a 95x95 pixel image).  Note that this property is
		persistant until the server restarts, and its global - so you can't just bump it
		down for faster processing of a small image, because that will effect concurrent
		requests on larger images.  Having this set to a large value will not effect
		your scanning performance unless you are passing in an image much larger than
		you need to - i.e. a 1000x1000 image that contains a 100x100 barcode in the upper
		left corner. --->
		<cfset sys = createObject("java", "java.lang.System")>
		<cfif Val(sys.getProperty("com.java4less.vision.maxarea")) LT 1000000>
			<cfset sys.setProperty("com.java4less.vision.maxarea", 1000000)>
		</cfif>

		<cfreturn this>
	</cffunction>

	<cffunction name="readFromImage" access="public" returntype="Array" output="yes" hint="Reads barcodes in from a ColdFusion image object. Returns an array, one entry for each barcode found.">
		<cfargument name="InputImage" type="any" required="true" hint="ColdFusion image object to read barcodes from">
		
		<cfset var local = StructNew()>
		<cfset local.ReturnArray = ArrayNew(1)>

		<!--- see how many color components the image has.  If its not 1 or 4 we need to convert it. --->
		<cfset local.ImageInfo = ImageInfo(Arguments.InputImage)>
		<cfif Not (local.ImageInfo.colormodel.num_color_components EQ 4 OR local.ImageInfo.colormodel.num_color_components EQ 1 )>
			<cfset ImageGrayScale(Arguments.InputImage)>
		</cfif>
		
		<!--- We need to pass the reader an RImage object, which needs to be passed a Buffered Image Object --->
		<cfset local.RImageData = CreateObject('java',"com.java4less.vision.RImage").init(ImageGetBufferedImage(Arguments.InputImage))>
		<cfset local.result = variables.Reader.read(local.RImageData)>
		
		<!--- loop over the returned array and create an easier to use structure that will be returned --->
		<cfset local.tmpByteArray = ArrayNew(1)>
		<cfloop from="1" to="#ArrayLen(local.result)#" index="local.j">
			<cfset local.ReturnArray[local.j] = StructNew()>
			<cfset local.ReturnArray[local.j].x = local.result[local.j].getX()>
			<cfset local.ReturnArray[local.j].y = local.result[local.j].getY()>
			<cfset local.ReturnArray[local.j].value = "">
			
			<!--- the value in the barcode is given to us as a byte array.
			We turn that into a string to its easier to use. --->
			<cfset local.tmpByteArray = local.result[local.j].getValue()>
			<cfloop from="1" to="#ArrayLen(local.tmpByteArray)#" index="local.i">
				<cfset local.ReturnArray[local.j].value = local.ReturnArray[local.j].value & Chr(local.tmpByteArray[local.i])>
			</cfloop>
		</cfloop>
		
		<cfreturn local.ReturnArray>
		
	</cffunction>


	<cffunction name="readFromFile" access="public" returntype="Array" output="no" hint="Reads barcodes in from an image file (formats?). Returns an array, one entry for each barcode found.">
		<cfargument name="InputFile" type="String" required="true" hint="Path to image file to read barcodes from.">
		
		<cfreturn readFromImage(ImageRead(Arguments.InputFile))>
	</cffunction>
	
	<cffunction name="createBarCode" access="public" returntype="Any" output="yes" hint="Creates a barcode and returns a ColdFusion image object containing the barcode.">
		<cfargument name="text" hint="Text to encode in barcode." required="true">
		<cfargument name="dotPixels" default="4">
		<cfargument name="encoding" default="E_ASCII" hint="One of the following: E_ASCII, E_AUTO, E_BASE256, E_C40, E_NONE, E_TEXT.  Only tested with E_ASCII.">
		<cfargument name="preferredFormat" default="C10X10" hint="Code representing the perferred generated barcode size.  Barcode will expand beyond this if necessary. See codes at bottom of this file.">
		<cfargument name="margin" default="0" hint="Pixels of margin around the barcode.  Only used on the top and left sides.">
		<cfargument name="width" default="200" hint="Width of the image containing the barcode">
		<cfargument name="height" default="200" hint="Height of the image containing the barcode">
		
		<!--- create an image to place this barcode into --->
		<cfset var ReturnImage = ImageNew('',Arguments.width,Arguments.height,'grayscale')>
		
		<!--- the writer is not thread safe, so we must create an instance of it for each request --->
		<cfset var Writer = CreateObject('java',"com.java4less.rdatamatrix.RDataMatrix").init()>
		
		<cfset Writer.code = Arguments.text>
		<cfset Writer.dotPixels = Arguments.dotPixels>
		<cfset Writer.encoding = Writer[Arguments.encoding]>
		<cfset Writer.preferredFormat = Writer[Arguments.preferredFormat]>
		<cfset Writer.margin = Arguments.margin>
		<cfset Writer.setSize(Arguments.width,Arguments.height)>
		
		<!--- now 'paint' the barcode into our ColdFusion image object --->
		<cfset Writer.paint(ImageGetBufferedImage(ReturnImage).createGraphics())>
		
		<cfreturn ReturnImage>
		
	</cffunction>

</cfcomponent>

<!--- 
These are the codes used for setting the generated barcode size (the preferredFormat
parameter of the createBarCode method). The barcode will expand to be larger than this
if necessary, but this should set the minimum size.  Note that these have no
relation to the actual image size.  That is set by the width and height arguments.
C10X10
C12X12
C14X14
C16X16
C18X18
C20X20
C22X22
C24X24
C26X26
C32X32
C36X36
C40X40
C44X44
C48X48
C52X52
C64X64
C72X72
C80X80
C88X88
C96X96
C104X104
C120X120
C132X132
C144X144
C8X18
C8X32
C12X26
C12X36
C16X36
C16X48
--->