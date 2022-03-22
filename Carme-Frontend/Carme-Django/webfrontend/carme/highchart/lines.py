"""tools to build Line charts parameters."""
from .highchart import HighChartsView
from .colors import next_color
from .base import JSONView

class HighchartPlotLineChartView(HighChartsView):
    y_axis_title = None

    def get_y_axis_options(self):
        return {"title": {"text": u"%s" % self.y_axis_title}}

    def get_x_axis_options(self):
        return {"categories": self.get_labels(), }

    def get_context_data(self, **kwargs):
        data = super(HighchartPlotLineChartView, self).get_context_data(**kwargs)
        data.update(
            {
                "labels": self.get_labels(),
                "xAxis": self.get_x_axis_options(),
                "series": self.get_series(),
                "yAxis": self.get_y_axis_options(),
            }
        )
        return data

    def get_providers(self):
        return []

    def get_markers(self):
        return []
