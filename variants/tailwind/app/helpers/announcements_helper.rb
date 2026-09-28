module AnnouncementsHelper
  # The Bootstrap payload styles `.unread-announcements` in app/assets/stylesheets. With Tailwind
  # there is no stylesheet to hook into, so the dot is built from utilities instead.
  def unread_announcements(user)
    last_announcement = Announcement.order(published_at: :desc).first
    return if last_announcement.nil?

    # Highlight announcements for anyone not logged in, cuz tempting
    if user.nil? || user.announcements_last_read_at.nil? || user.announcements_last_read_at < last_announcement.published_at
      "before:mr-1.5 before:inline-block before:h-2 before:w-2 before:rounded-full before:bg-red-500 before:content-['']"
    end
  end

  def announcement_class(type)
    {
      "new" => "text-green-600",
      "update" => "text-amber-600",
      "fix" => "text-red-600",
    }.fetch(type, "text-green-600")
  end
end
