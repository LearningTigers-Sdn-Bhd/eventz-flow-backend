class FeedbackFormSummary
  # filters: { ticket_type_id:, from:, to: } (see FeedbackResponseScope)
  def self.call(form, filters = {})
    new(form, filters).call
  end

  def initialize(form, filters = {})
    @form = form
    @filters = filters
    @responses = FeedbackResponseScope.call(form, filters)
    @answers_by_question = Hash.new { |hash, key| hash[key] = Hash.new(0) }
  end

  def call
    grouped_answers.each do |(question_id, answer_text), count|
      @answers_by_question[question_id][answer_text] = count
    end

    questions = @form.feedback_questions.map { |question| serialize_question(question) }

    {
      total_responses: total_responses,
      last_submitted_at: @responses.maximum(:submitted_at),
      response_rate: response_rate,
      overall_average: overall_average(questions),
      overall_satisfied_percent: overall_satisfied_percent(questions),
      timeline: timeline,
      questions: questions
    }
  end

  private

  def total_responses
    @total_responses ||= @responses.count
  end

  def response_ids
    @response_ids ||= @responses.pluck(:id)
  end

  def grouped_answers
    FeedbackAnswer.where(feedback_response_id: response_ids)
                  .where("BTRIM(feedback_answers.answer_text) <> ''")
                  .group(:feedback_question_id, :answer_text)
                  .count
  end

  # Responses from checked-in, still-valid tickets, out of all such tickets.
  def response_rate
    eligible = FeedbackResponseScope.eligible_tickets(@form.event, ticket_type_id: @filters[:ticket_type_id])
    eligible_count = eligible.count
    responded = eligible.where(id: @responses.select(:ticket_id)).count
    {
      eligible: eligible_count,
      responded: responded,
      percent: eligible_count.zero? ? nil : (responded * 100.0 / eligible_count).round(1)
    }
  end

  def timeline
    # sort_by, not SQL "ORDER BY 1": in a grouped count the first column is the count.
    @responses.group('DATE(feedback_responses.submitted_at)').count
              .sort_by { |date, _| date }
              .map { |date, count| { date: date.to_s, count: } }
  end

  def overall_average(questions)
    ratings = questions.select { |q| q[:question_type] == 'rating' }
    answered = ratings.sum { |q| q[:answered_count] }
    return nil if answered.zero?

    (ratings.sum { |q| q[:average] * q[:answered_count] } / answered).round(1)
  end

  def overall_satisfied_percent(questions)
    ratings = questions.select { |q| q[:question_type] == 'rating' }
    answered = ratings.sum { |q| q[:answered_count] }
    return nil if answered.zero?

    (ratings.sum { |q| q[:satisfied_count] } * 100.0 / answered).round(1)
  end

  # How many responses could actually see each question, following branching.
  def seen_counts
    @seen_counts ||= begin
      questions = @form.feedback_questions.to_a
      routing = FeedbackRouting.new(questions, continuous: @form.continuous?)
      if routing.branching_form?
        answers = FeedbackAnswer.where(feedback_response_id: response_ids)
                                .pluck(:feedback_response_id, :feedback_question_id, :answer_text)
                                .group_by(&:first)
        response_ids.each_with_object(Hash.new(0)) do |id, counts|
          given = (answers[id] || []).to_h { |_, question_id, text| [question_id, text] }
          routing.reachable_ids(given).each { |question_id| counts[question_id] += 1 }
        end
      else
        questions.to_h { |question| [question.id, total_responses] }
      end
    end
  end

  # Average rating per ticket type, for each rating question. Only useful when
  # more than one ticket type has responses.
  def rating_by_ticket_type
    @rating_by_ticket_type ||= begin
      rating_ids = @form.feedback_questions.select(&:rating?).map(&:id)
      rows = FeedbackAnswer.joins(feedback_response: :ticket)
                           .where(feedback_response_id: response_ids, feedback_question_id: rating_ids)
                           .where("feedback_answers.answer_text ~ '^[1-5]$'")
                           .group('feedback_answers.feedback_question_id', 'tickets.ticket_type_id')
                           .pluck('feedback_answers.feedback_question_id', 'tickets.ticket_type_id',
                                  Arel.sql('AVG(CAST(feedback_answers.answer_text AS integer))'),
                                  Arel.sql('COUNT(*)'))
      names = TicketType.where(id: rows.map { |row| row[1] }.uniq).pluck(:id, :name).to_h
      rows.group_by(&:first).transform_values do |list|
        list.map do |_, type_id, average, count|
          { ticket_type_id: type_id, ticket_type_name: names[type_id], average: average.to_f.round(1), count: }
        end
      end
    end
  end

  def serialize_question(question)
    answer_counts = @answers_by_question[question.id]
    {
      id: question.id,
      question_text: question.question_text,
      question_type: question.question_type,
      required: question.required,
      answered_count: answer_counts.values.sum,
      seen_count: seen_counts[question.id] || 0
    }.merge(question_statistics(question, answer_counts))
  end

  def question_statistics(question, answer_counts)
    case question.question_type
    when 'rating'
      distribution = (1..5).index_with { |rating| answer_counts[rating.to_s] }
      answered_count = distribution.values.sum
      average = answered_count.zero? ? 0.0 :
        (distribution.sum { |rating, count| rating * count }.to_f / answered_count).round(1)
      satisfied_count = distribution[4] + distribution[5]
      ticket_types = rating_by_ticket_type[question.id] || []
      {
        average:,
        distribution: distribution.transform_keys(&:to_s),
        satisfied_count:,
        satisfied_percent: answered_count.zero? ? nil : (satisfied_count * 100.0 / answered_count).round(1),
        by_ticket_type: ticket_types.length > 1 ? ticket_types : []
      }
    when 'text'
      { latest: latest_text_answers.fetch(question.id, []) }
    when 'yes_no'
      { options: choice_options(%w[Yes No], answer_counts, question, yes_no: true) }
    when 'single_choice'
      { options: choice_options(Array(question.options), answer_counts, question) }
    when 'multi_choice'
      { options: choice_options(Array(question.options), answer_counts, question, multi_choice: true) }
    else
      {}
    end
  end

  def choice_options(labels, answer_counts, question, yes_no: false, multi_choice: false)
    counts = Hash.new(0)
    answer_counts.each do |answer_text, count|
      if multi_choice
        selected = JSON.parse(answer_text)
        selected.uniq.each { |label| counts[label] += count if labels.include?(label) } if selected.is_a?(Array)
      elsif yes_no
        label = { 'yes' => 'Yes', 'no' => 'No' }[answer_text]
        counts[label] += count if label
      else
        counts[answer_text] += count if labels.include?(answer_text)
      end
    rescue JSON::ParserError
      next
    end

    answered_count = @answers_by_question[question.id].values.sum
    labels.map do |label|
      count = counts[label]
      { label:, count:, percent: answered_count.zero? ? 0.0 : (count * 100.0 / answered_count).round(1) }
    end
  end

  # One query for all text questions: latest 5 non-blank answers each.
  def latest_text_answers
    @latest_text_answers ||= begin
      ranked = FeedbackAnswer.joins(:feedback_response, :feedback_question)
                             .where(feedback_responses: { id: response_ids })
                             .where(feedback_questions: { question_type: :text })
                             .where("BTRIM(feedback_answers.answer_text) <> ''")
                             .select(
                               'feedback_answers.feedback_question_id, feedback_answers.answer_text, ' \
                               'feedback_responses.submitted_at, ' \
                               'ROW_NUMBER() OVER (PARTITION BY feedback_answers.feedback_question_id ' \
                               'ORDER BY feedback_responses.submitted_at DESC, feedback_answers.id DESC) AS rank'
                             )
      FeedbackAnswer.from(ranked, :ranked)
                    .where('ranked.rank <= 5')
                    .order('ranked.rank')
                    .pluck('ranked.feedback_question_id', 'ranked.answer_text', 'ranked.submitted_at')
                    .group_by(&:first)
                    .transform_values { |rows| rows.map { |_, answer_text, submitted_at| { answer_text:, submitted_at: } } }
    end
  end
end
