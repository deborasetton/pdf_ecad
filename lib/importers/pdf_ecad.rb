module Importers

  ##
  # Parse a PDF file from Ecad.
  class PdfEcad

    CATEGORIES = {
      "CA" => "Author",
      "E"  => "Publisher",
      "V"  => "Versionist",
      "SE" => "SubPublisher"
    }

    # Match and capture the role and share columns, which are separated by
    # whitespace.
    RE_ROLE_SHARE = /\s+(\w{1,2})\s{1,3}([0-9,]+)/

    # Match an IPI/CAE number.
    RE_IPI        = /([0-9.]+)/

    # Match letters.
    RE_LETTERS    = /([A-Z]+)/

    # Match if the first column of the line is a number. Columns are separated
    # by whitespace.
    RE_FIRST_COLUMN_IS_NUMBER = /\A\d+\s/

    ##
    # Match if the line is a work line: starts with a number and has an
    # identifier or a "missing identifier" on the 2nd column.
    RE_WORK_LINE = /\A\d+\s+(T-|-)/

    def initialize(file_path)
      unless File.exist?(file_path)
        raise ArgumentError, "File not found: #{file_path}"
      end

      @file_path = file_path
    end

    def works
      return @works if @works

      @works = []

      content_lines.each do |line|
        if work?(line)
          @works << work(line)
        else
          @works.last[:right_holders] ||= []
          @works.last[:right_holders] << right_holder(line)
        end
      end

      @works
    end

    def right_holder(line)
      return if work?(line)

      id, name, pseudo, ipi, society, role, share = right_holder_tokens(line)

      hsh = {
        name: name,
        role: CATEGORIES[role],
        society_name: society,
        ipi: ipi,
        external_ids: [{
          source_name: 'Ecad',
          source_id: id
        }],
        pseudos: [],
        share: share
      }

      if pseudo
        hsh[:pseudos] << {
          name: pseudo,
          main: true
        }
      end

      hsh
    end

    def work(line)
      # Columns are separated by a minimum of 4 spaces.
      tokens = line.split(/\s{4,}/)

      {
        iswc:       tokens[1],
        title:      tokens[2],
        situation:  tokens[3],
        created_at: tokens[4],
        external_ids: [{
          source_name: 'Ecad',
          source_id: tokens[0]
        }]
      }
    end

    private

    ##
    # Return a PDF reader object for the file.
    def reader
      return @reader if @reader
      @reader = PDF::Reader.new(@file_path)
    end

    ##
    # Return an array of content lines, i.e., lines that are either a work
    # line or a right holder line. Other lines are simply ignored for now.
    def content_lines
      lines = []

      reader.pages.each do |page|
        page.text.split("\n").each do |line|
          if line =~ RE_FIRST_COLUMN_IS_NUMBER
            lines << line
          end
        end
      end

      lines
    end

    ##
    # Return whether the line is a work line.
    def work?(line)
      line =~ RE_WORK_LINE
    end

    ##
    # Split a right_holder line into its tokens.
    #
    # Mandatory tokens: id, name, role, share.
    # Optional tokens: pseudonym, ipi, society.
    # Ignored tokens (for now): date, link (last two columns).
    def right_holder_tokens(line)
      id, name, pseudo, ipi, society, role, share = []

      # We split the line around the role and share, since this is the most
      # well-behaved part of the line.
      before_role, role, share, after_share = line.split(RE_ROLE_SHARE)

      # Split the leftmost columns using a minimum of 2 spaces as separator.
      # Since the IPI and society name are separated by a single space, this
      # will *NOT* split these two columns; they will be split later.
      before_role_tokens = before_role.split(/\s{2,}/)

      if before_role_tokens.count == 2
        # This is the easiest case: since there are only two leftmost tokens,
        # they *must* be the mandatory ones (id and name).
        id, name = before_role_tokens

      elsif before_role_tokens.count == 3
        # This is the fuzziest case, because there isn't an obvious way to
        # detect if the 3rd column is a pseudonym or a society name.
        # We use a distance heuristic: if the column is closest to the left,
        # then assume it's a pseudo. Else, assume it's a society.

        # Regex to match and capture surrounding spaces.
        md = line.match(Regexp.new('(\s+)' + before_role_tokens[2] + '(\s+)'))

        if md[1].size > md[2].size
          # The number of spaces on the left if greater, so the column is more
          # to the right.
          id, name, society = before_role_tokens
        else
          id, name, pseudo = before_role_tokens
        end

      elsif before_role_tokens.count == 4
        # This is the most complete case: all columns are present.
        id, name, pseudo, ipi_and_society = before_role_tokens

        # Get the IPI, if present.
        if (md = ipi_and_society.match(RE_IPI))
          ipi = md[1].gsub('.', '')
        end

        # Get the society name, if present.
        if (md = ipi_and_society.match(RE_LETTERS))
          society = md[1]
        end

      else
        # Could be Rails.logger.error(...).
        # This means the PDF format has changed somehow.
        raise "Unexpected number of tokens on right holder line: #{before_role_tokens.count}"
      end

      share = share.sub(',', '.').to_f

      [id, name, pseudo, ipi, society, role, share]
    end

  end
end
