/// I8: cuối tuần (thứ 7/CN theo giờ máy) nhân đôi coin thưởng.
bool isWeekendEvent(DateTime now) =>
    now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
