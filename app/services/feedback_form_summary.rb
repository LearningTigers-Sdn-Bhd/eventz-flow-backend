class FeedbackFormSummary
  def self.call(form)
    new(form).call
  end

  def initialize(form)
    @form = form
    @answers_by_question = Hash.new { |hash, key| hash[key] = Hash.new(0) }
  end

  def call
    grouped_answers.each do |(question_id, answer_text), count|
      @answers_by_question[question_id][answer_text] = count
    end

    {
      total_responses: @form.feedback_responses.count,
      last_submitted_at: @form.feedback_responses.maximum(:submitted_at),
      questions: @form.feedback_questions.map { |question| serialize_question(question) }
    }
  end

  private

  def grouped_answers
    FeedbackAnswer.joins(:feedback_response)
                  .where(feedback_responses: { feedback_form_id: @form.id })
                  .where("BTRIM(feedback_answers.answer_text) <> ''")
                  .group(:feedback_question_id, :answer_text)
                  .count
  end

  def serialize_question(question)
    answer_counts = @answers_by_question[question.id]
    {
      id: question.id,
      question_text: question.question_text,
      question_type: question.question_type,
      required: question.required,
      answered_count: answer_counts.values.sum
    }.merge(question_statistics(question, answer_counts))
  end

  def question_statistics(question, answer_counts)
    case question.question_type
    when 'rating'
      distribution = (1..5).index_with { |rating| answer_counts[rating.to_s] }
      answered_count = distribution.values.sum
      average = answered_count.zero? ? 0.0 :
        (distribution.sum { |rating, count| rating * count }.to_f / answered_count).round(1)
      { average:, distribution: distribution.transform_keys(&:to_s) }
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
                             .where(feedback_responses: { feedback_form_id: @form.id })
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
