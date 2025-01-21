# Purpose: This script prompts the user to select a video text track file 
# 		   file to import into Datavyu and will create columns 
#          containing the whisper transcription. 
# Written by: Trinity Wang and Aaron G. Beckner
# Last edited: 01.01.2023

require 'Datavyu_API.rb'

begin 

########################################################################################
	# Prompt user for input file.
	java_import javax::swing::JFileChooser
	java_import javax::swing::filechooser::FileNameExtensionFilter


	jfc = JFileChooser.new() #jfc stands for JFileChooser
	jfc.setAcceptAllFileFilterUsed(false)
	jfc.setMultiSelectionEnabled(false)
	jfc.setDialogTitle('Select file to import.')

	ret = jfc.showSaveDialog(javax.swing.JPanel.new())

	if ret != JFileChooser::APPROVE_OPTION
		puts "Invalid selection. Aborting."
		return
	end

	originalFile = jfc.getSelectedFile().getPath()
##################################
	
	originalContent = File.readlines(originalFile) #creates new array called originalContent where each line of the txt file is saved

	#creates two new arrays called words and times that hold the data we want to transfer to datavyu
	words = [] 
	wordsIndex = 0

	times = []
	timesIndex = 0

	#puts lines that have "-->" in the times array and all other lines in words array
	for currentLine in originalContent
		if currentLine.include?"-->"
			times[timesIndex] = currentLine
			timesIndex = timesIndex + 1
		else
			words[wordsIndex] = currentLine
			wordsIndex = wordsIndex + 1
		end 
	end

	#creates new array called trimmedWords that gets rid of empty lines and the first line that says "WEBVTT"
	trimmedWords = []
	trimmedWordsIndex = 0

	for currentLine in words
		if ("a".."z").cover?(currentLine[0]) || ("A".."Z").cover?(currentLine[0])
			trimmedWords[trimmedWordsIndex] = currentLine.delete"\n"
			trimmedWordsIndex = trimmedWordsIndex + 1
		end
	end

	trimmedWords.shift

	#creates 2 new arrays called onset and offset
	onset = []
	offset = []
	index1 = 0

	#splits each line in times array in two whenever there's a "-->" character
	#left side saved in onset array and right side saved in offset array
	for currentLine in times
		splitArray = currentLine.split("-->")
		onset[index1] = splitArray[0].strip
		offset[index1] = splitArray[1].strip
		index1 = index1 + 1
	end


	#creates new array called onsetMiliseconds
	onsetMiliseconds = []
	index2 = 0

	#converts 00:00.000 format in onset array to miliseconds in onsetMiliseconds array
	for currentTime in onset 
		onsetMinutes = currentTime.slice(0..1).to_i
		onsetMiliseconds[index2] = onsetMinutes * 60 * 1000
		onsetSeconds = currentTime.slice(3..4).to_i
		onsetMiliseconds[index2] = onsetMiliseconds[index2] + onsetSeconds * 1000
		onsetSecondFractions = currentTime.slice(6..8).to_i
		onsetMiliseconds[index2] = onsetMiliseconds[index2] + onsetSecondFractions
		index2 = index2 + 1
	end


	#creates new array called offsetMiliseconds
	offsetMiliseconds = []
	index3 = 0 

	#converts 00:00.000 format in offset array to miliseconds in offsetMiliseconds array
	for currentTime in offset 
		offsetMinutes = currentTime.slice(0..1).to_i
		offsetMiliseconds[index3] = offsetMinutes * 60 * 1000
		offsetSeconds = currentTime.slice(3..4).to_i
		offsetMiliseconds[index3] = offsetMiliseconds[index3] + offsetSeconds * 1000
		offsetSecondFractions = currentTime.slice(6..8).to_i
		offsetMiliseconds[index3] = offsetMiliseconds[index3] + offsetSecondFractions
		index3 = index3 + 1
	end

########################################################################################
	# creates a column called "speech" that we'll add to datavyu file
	speechColumn = new_column('transcript', 'p_c_e', 'content')
		
		# create cells
		onsetMiliseconds.size.times do
			speechColumn.make_new_cell()
		end 

		# fills in each transcribe cells with speech content, onset, and offset
		cellIndex = 0
		for speechColumnCell in speechColumn.cells
			speechColumnCell.change_code("content", trimmedWords[cellIndex])
			speechColumnCell.change_code("onset", onsetMiliseconds[cellIndex])
			speechColumnCell.change_code("offset", offsetMiliseconds[cellIndex])
			cellIndex = cellIndex + 1
		end
		
		# create speech column
		set_column(speechColumn)

	# creates a column called "transcript_QA" that we'll add to the datavyu file
	transcript_qa = createColumn("transcript_QA", 'OnsetError', 'ContentError', 'OmittedUtterance', 'HallucinatedUtterance', 'SpeakerChange')

		# create cells
	    onsetMiliseconds.size.times do
			transcript_qa.make_new_cell()
		end 

		# fills in each transcribe_qa cells with onset and offset
		cellIndex = 0
		for transcript_qaCell in transcript_qa.cells
			transcript_qaCell.change_code("onset", onsetMiliseconds[cellIndex])
			transcript_qaCell.change_code("offset", offsetMiliseconds[cellIndex])
			cellIndex = cellIndex + 1
		end

		# create quality assurance column
		set_column(transcript_qa)

		# create reliability coder initials column
		transcript_initials = createColumn("transcript_initials","write your initials")
		set_column(transcript_initials)

		# creates a column called notes
		transcript_notes = createColumn("transcript_notes","write your notes")
		set_column(transcript_notes)


end
