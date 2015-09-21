module Oec
  class Task
    include ClassLogger

    LOG_DIRECTORY = Rails.root.join('tmp', 'oec')

    def initialize(opts)
      @log = []
      @remote_drive = Oec::RemoteDrive.new
      @term_code = opts.delete :term_code
      @date_time = opts[:date_time] || DateTime.now
      @opts = opts
      @course_code_filter = if opts[:dept_names]
                             {dept_name: opts[:dept_names].split}
                           elsif opts[:dept_codes]
                             {dept_code: opts[:dept_codes].split}
                           else
                             {dept_name: Oec::CourseCode.included_dept_names}
                           end
    end

    def run
      log :info, "Starting #{self.class.name}"
      run_internal
      true
    rescue => e
      log :error, "#{self.class.name} aborted with error: #{e.message}\n#{e.backtrace.join "\n\t"}"
      nil
    ensure
      write_log
    end

    private

    def copy_file(file, dest_folder)
      return if @opts[:local_write]
      @remote_drive.check_conflicts_and_copy_file(file, dest_folder,
        on_success: -> { log :debug, "Copied file '#{file.title}' to remote drive folder '#{dest_folder.title}'" }
      )
    end

    def create_folder(folder_name, parent=nil)
      return if @opts[:local_write]
      @remote_drive.check_conflicts_and_create_folder(folder_name, parent,
        on_conflict: :error,
        on_creation: -> { log :debug, "Created remote folder '#{folder_name}'" }
      )
    end

    def datestamp
      @date_time.strftime '%F'
    end

    def export_sheet(worksheet, dest_folder)
      if @opts[:local_write]
        worksheet.write_csv
        log :debug, "Exported worksheet to local file #{worksheet.csv_export_path}"
      else
        upload_worksheet(worksheet, worksheet.export_name, dest_folder)
      end
    end

    def export_sheet_headers(klass, dest_folder)
      worksheet = klass.new
      if @opts[:local_write]
        worksheet.write_csv
        log :debug, "Exported to header-only local file #{worksheet.csv_export_path}"
      else
        @remote_drive.check_conflicts_and_upload(worksheet, klass.export_name, Oec::Worksheet, dest_folder,
          on_success: -> { log :debug, "Uploaded header-only sheet '#{klass.export_name}' to remote drive folder '#{dest_folder.title}'" })
      end
    end

    def find_or_create_folder(folder_name, parent=nil)
      @remote_drive.check_conflicts_and_create_folder(folder_name, parent,
        on_conflict: :return_existing,
        on_creation: -> { log :debug, "Created remote folder '#{folder_name}'" }
      )
    end

    def find_or_create_today_subfolder(category_name)
      return if @opts[:local_write]
      parent = @remote_drive.find_nested([@term_code, category_name], on_failure: :error)
      find_or_create_folder(datestamp, parent)
    end

    def get_supplemental_worksheet(klass)
      if (supplemental_course_sheet = @remote_drive.find_nested [@term_code, 'supplemental_sources', klass.export_name])
        klass.from_csv @remote_drive.export_csv(supplemental_course_sheet)
      end
    end

    def log(level, message)
      logger.send level, message
      @log << "[#{Time.now}] #{message}"
    end

    def timestamp
      @date_time.strftime '%H%M%S'
    end

    def upload_file(path, remote_name, type, folder)
      @remote_drive.check_conflicts_and_upload(path, remote_name, type, folder,
        on_success: -> { log :debug, "Uploaded item #{path} to remote drive folder '#{folder.title}'" })
    end

    def upload_worksheet(worksheet, title, folder)
      @remote_drive.check_conflicts_and_upload(worksheet, title, Oec::Worksheet, folder,
        on_success: -> { log :debug, "Uploaded sheet '#{title}' to remote drive folder '#{folder.title}'" })
    end

    def write_log
      log_name = "#{timestamp}_#{self.class.name.demodulize.underscore}.log"
      log :debug, "Exporting log file '#{log_name}'"
      FileUtils.mkdir_p LOG_DIRECTORY unless File.exists? LOG_DIRECTORY
      log_path = LOG_DIRECTORY.join log_name
      File.open(log_path, 'wb') { |f| f.puts @log }
      if @opts[:local_write]
        logger.debug "Wrote log file to path #{log_path}"
      else
        if (reports_today = find_or_create_today_subfolder('reports'))
          begin
            upload_file(log_path, log_name, 'text/plain', reports_today)
          ensure
            File.delete log_path
          end
        end
      end
    rescue => e
      logger.error "Could not write log: #{e.message}\n#{e.backtrace.join "\n\t"}"
    end

  end
end