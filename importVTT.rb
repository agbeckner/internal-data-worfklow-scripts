# Purpose: This script processes and imports transcript files into Datavyu. 
# 
# Supported Formats:
#   - WebVTT (.vtt)
#   - SubRip (.srt) [planned]
#   - Plain Text (.txt) [planned]
#
# Features:
#   - File format validation
#   - Timestamp conversion
#   - Quality assurance workflow
#   - Support for multiple subtitle formats [planned]
# 
# Usage:
#   1. Run script
#   2. Select subtitle/transcript file when prompted
#   3. Script will create necessary columns in Datavyu:
#      - transcript: Contains timestamped transcription 
#.       with empty codes where the speaker can be labelled
#      - transcript_QA: For marking various types of errors
#.       so cells can be conditionally copy/pasted to a  
#        transcript_clean column when no errors are detected
#      - transcript_initials: For coder identification
#      - transcript_notes: For additional observations
# Authors: Aaron G. Beckner & Trinity Wang
# Last edited: 01-14-2025

require 'Datavyu_API.rb'

# Configuration constants
SUPPORTED_FORMATS = {
  'vtt' => 'WebVTT Subtitles'
  # Add additional formats here as needed:
  # 'srt' => 'SubRip Subtitles',
  # 'txt' => 'Plain Text Transcripts'
}

# Column configurations
COLUMN_CONFIGS = {
  transcript: {
    name: 'transcript',
    codes: ['p_c_e', 'content'],  # Codes for speaker labeling and transcription content
    required: true
  },
  qa: {
    name: 'transcript_QA',
    codes: ['OnsetError', 'ContentError', 'OmittedUtterance', 'HallucinatedUtterance', 'SpeakerChange'], # quality assurance error codes
    required: true
  },
  initials: {
    name: 'transcript_initials',
    codes: ['coder_initials'], # Optional Coder initials column
    required: false
  },
  notes: {
    name: 'transcript_notes',
    codes: ['notes'], # Optional notes column
    required: false
  }
}

begin
  # Import Java classes for GUI file selection
  java_import javax.swing.JFileChooser
  java_import javax.swing.filechooser.FileNameExtensionFilter
  java_import javax.swing.JFrame

  # Sets up the file chooser dialog
  def setup_file_chooser
    # Create a parent frame for the dialog
    frame = JFrame.new("Import Transcript")
    frame.setDefaultCloseOperation(JFrame::DISPOSE_ON_CLOSE)
    frame.setSize(200, 200)
    frame.setLocationRelativeTo(nil)
    
    # Initialize and configure file chooser dialog
    jfc = JFileChooser.new
    jfc.setAcceptAllFileFilterUsed(false)
    jfc.setMultiSelectionEnabled(false)
    jfc.setDialogTitle('Select transcript file to import')
    
    # Add file filters for supported formats
    SUPPORTED_FORMATS.each do |format, description|
      extensions = [format].to_java(:String)
      filter = FileNameExtensionFilter.new(description, extensions)
      jfc.addChoosableFileFilter(filter)
    end
    
    [frame, jfc]
  end

  # Validates that the selected file has a supported format
  def validate_file_format(file_path)
    extension = File.extname(file_path)[1..-1]
    raise "Unsupported file format: .#{extension}" unless SUPPORTED_FORMATS.key?(extension)
    true
  end

def parse_timestamp(time_str)
  # Ensure the timestamp matches the expected format
  unless time_str.match(/^\d{2}:\d{2}:\d{2}\.\d{3}$/)
    raise "Invalid timestamp format: #{time_str}. Expected format: HH:MM:SS.mmm"
  end

  # Remove colons and periods for direct conversion
  time_str.delete(":.").to_i
end

  # Processes transcript content, separating timestamps and transcription text
  def process_content(content)
    times = [] # Stores timestamp lines
    words = [] # Stores transcription text
    
     content.each do |line|
      if line.include?("-->")
        times << line # Identify timestamp lines
      else
        words << line # Identify transcription text
      end
    end
    
    # Filter and clean up transcription lines
    words = words.select { |line| line.match(/^[a-zA-Z]/) }
    words.shift if words.first&.strip == 'WEBVTT'
    words = words.map(&:strip)
    
    # Convert timestamps to onset/offset in milliseconds
    timestamps = times.map do |time_line|
      onset, offset = time_line.split('-->').map(&:strip)
      {
        onset: parse_timestamp(onset),
        offset: parse_timestamp(offset)
      }
    end
    
    [words, timestamps]
  end

  # Creates a new column in Datavyu with optional data
  def create_column(type, config, data = nil)
    column = new_column(config[:name], *config[:codes])
    
    if data
      if type == :transcript
        # Populate transcript column with content and timestamps
        data[:content].size.times do |i|
          cell = column.make_new_cell
          config[:codes].each do |code|
            value = data[:content][i] if code == 'content'
            cell.change_code(code, value)
          end
          cell.change_code('onset', data[:timestamps][i][:onset])
          cell.change_code('offset', data[:timestamps][i][:offset])
        end
      elsif type == :qa
        # Create empty cells for QA column with matching timestamps
        data[:timestamps].size.times do |i|
          cell = column.make_new_cell
          cell.change_code('onset', data[:timestamps][i][:onset])
          cell.change_code('offset', data[:timestamps][i][:offset])
        end
      end
    end
    
    column
  end

  # Main execution flow
  puts "Starting transcript import..."

  # Setup and show file chooser
  frame, jfc = setup_file_chooser
  frame.setVisible(true)
  
  result = jfc.showOpenDialog(frame) # Open file chooser
  frame.dispose

  if result != JFileChooser::APPROVE_OPTION
    puts "No file selected. Aborting."
    return
  end

  file_path = jfc.getSelectedFile.getPath
  validate_file_format(file_path) # Ensure selected file is valid

  puts "Reading file: #{file_path}"
  content = File.readlines(file_path)
  words, timestamps = process_content(content) # Parse file content

  puts "Creating Datavyu columns..."
  COLUMN_CONFIGS.each do |type, config|
    next unless config[:required] # Only process required columns
    
    column_data = {
      content: words,
      timestamps: timestamps
    }
    
    puts "Creating column: #{config[:name]}"
    column = create_column(type, config, column_data) # Create column in Datavyu
    set_column(column)
  end

  puts "Import completed successfully!"

rescue => e
  puts "Error: #{e.message}" # Handle and display errors
  puts e.backtrace if ENV['DEBUG']
end
